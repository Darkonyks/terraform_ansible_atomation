# Outputs for DC Automation Terraform Configuration

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.dc_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = var.use_elastic_ip ? aws_eip.dc_server_eip[0].public_ip : aws_instance.dc_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.dc_server.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.dc_server.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.dc_server_sg.id
}

output "key_pair_name" {
  description = "Name of the key pair"
  value       = aws_key_pair.dc_automation_key.key_name
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.windows_server_2016.id
}

output "ami_name" {
  description = "AMI name used for the instance"
  value       = data.aws_ami.windows_server_2016.name
}

output "rdp_connection" {
  description = "RDP connection string"
  value       = "mstsc /v:${var.use_elastic_ip ? aws_eip.dc_server_eip[0].public_ip : aws_instance.dc_server.public_ip}:3389"
}

output "iis_url" {
  description = "IIS web server URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.dc_server_eip[0].public_ip : aws_instance.dc_server.public_ip}"
}

output "get_password_command" {
  description = "AWS CLI command to get Windows password"
  value       = "aws ec2 get-password-data --instance-id ${aws_instance.dc_server.id} --priv-launch-key ./dc-automation-key.pem --region ${var.aws_region}"
}

output "powershell_get_password_command" {
  description = "PowerShell command to get Windows password"
  value       = "Get-EC2PasswordData -InstanceId ${aws_instance.dc_server.id} -PemFile './dc-automation-key.pem' -Region ${var.aws_region}"
}

output "deployment_summary" {
  description = "Deployment summary information"
  value = {
    instance_id     = aws_instance.dc_server.id
    public_ip       = var.use_elastic_ip ? aws_eip.dc_server_eip[0].public_ip : aws_instance.dc_server.public_ip
    private_ip      = aws_instance.dc_server.private_ip
    server_name     = var.server_name
    domain_name     = var.domain_name
    instance_type   = var.instance_type
    region          = var.aws_region
    environment     = var.environment
  }
}
