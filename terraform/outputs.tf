output "instance_public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance."
  value       = aws_instance.web.public_dns
}

output "ssh_command" {
  description = "Command to SSH into the EC2 instance."
  value       = "ssh -i ~/.ssh/github_actions_ec2_key ${var.ec2_user}@${aws_instance.web.public_ip}"
  # ~/.ssh/github_actions_ec2_key ist der lokale Pfad zu deinem privaten Schlüssel
}