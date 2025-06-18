# --- Netzwerk ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true # Wichtig für öffentlichen Zugriff
  availability_zone = data.aws_availability_zones.available.names[0] # Nimmt die erste verfügbare AZ
  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Sicherheitsgruppe ---
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HTTP von überall
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH von überall (Für Produktion einschränken!)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# --- SSH Key Pair ---
resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  # Der öffentliche Schlüssel wird in der CI-Pipeline anders bereitgestellt,
  # nicht direkt aus einer lokalen Datei gelesen.
  # Für lokale Tests könntest du 'public_key = file(var.public_ssh_key_path)' verwenden.
  # In CI wird der Inhalt des Public Keys als Variable oder direkt übergeben.
  # Wir werden dies in der GitHub Action dynamischer handhaben oder den Public Key als Secret speichern.
  # Für diese Aufgabe vereinfachen wir es und gehen davon aus, der Public Key wird als Variable übergeben.
  # In der CI-Pipeline wird der Inhalt von SSH_PUBLIC_KEY (ein weiteres Secret) verwendet.
  public_key = var.ssh_public_key_content # Diese Variable definieren wir noch in variables.tf für CI
}

# --- EC2 Instanz ---
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id # Aktuelles Ubuntu LTS AMI
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name      = aws_key_pair.deployer.key_name
  associate_public_ip_address = true # Sicherstellen, dass sie eine öffentliche IP bekommt

  user_data = <<-EOF
            #!/binbash
            sudo apt-get update -y
            sudo apt-get install -y nginx
            sudo systemctl start nginx
            sudo systemctl enable nginx
            sudo mkdir -p /var/www/html/app
            sudo chown -R ${var.ec2_user}:${var.ec2_user} /var/www/html/app
            # Einfacher Health Check Endpunkt
            echo "Healthy" | sudo tee /var/www/html/health.html > /dev/null
            # Default Nginx Config so anpassen, dass sie /var/www/html/app serviert
            # oder eine neue Config erstellen und die default deaktivieren.
            # Hier ein einfacher Weg, die Default-Seite zu ersetzen,
            # später wird der Inhalt durch SCP überschrieben.
            # sudo sed -i 's|/usr/share/nginx/html|/var/www/html/app|g' /etc/nginx/sites-available/default
            # sudo systemctl reload nginx
            # Besser: Eigene Nginx-Konfiguration erstellen
            cat <<EOT_NGINX_CONF | sudo tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html/app; # Hierhin wird der Build-Output kopiert
    index index.html index.htm;

    server_name _;

    location / {
            try_files \$uri \$uri/ /index.html;
    }
}
EOT_NGINX_CONF
            sudo systemctl reload nginx
            EOF

  tags = {
    Name = "${var.project_name}-web-instance"
  }
}

# --- Datenquellen für AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"] # Beispiel für Ubuntu 20.04
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "aws_availability_zones" "available" {}