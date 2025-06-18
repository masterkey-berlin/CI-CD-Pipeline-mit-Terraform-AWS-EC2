variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  # Default kann hier gesetzt oder über ENV Var/Secret in CI übergeben werden
}

variable "project_name" {
  description = "A name prefix for resources."
  type        = string
  default     = "my-react-app"
}

variable "ssh_key_name" {
  description = "Name for the EC2 SSH key pair."
  type        = string
  default     = "deployer-key"
}

variable "public_ssh_key_path" {
  description = "Path to the public SSH key file to be uploaded to AWS for EC2 access."
  type        = string
  default     = "~/.ssh/github_actions_ec2_key.pub" # Lokaler Pfad, in CI wird der Inhalt anders übergeben
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ec2_user" {
  description = "Default username for the EC2 instance AMI."
  type        = string
  default     = "ubuntu" # Anpassen, falls anderes AMI
}

variable "ssh_public_key_content" {
  description = "Content of the public SSH key."
  type        = string
  sensitive   = true # Damit der Wert nicht in Logs angezeigt wird
}