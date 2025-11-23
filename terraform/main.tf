# DC Automation - Terraform + Ansible Infrastructure
# Author: Darko Nedic
# Version: 2.0 - Pure Infrastructure as Code

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Data source for latest Windows Server 2016 AMI
data "aws_ami" "windows_server_2016" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security Group for Domain Controller
resource "aws_security_group" "dc_server_sg" {
  name_prefix = "dc-server-"
  description = "Security group for Domain Controller"
  vpc_id      = data.aws_vpc.default.id

  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "RDP access"
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # DNS (TCP)
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "DNS TCP"
  }

  # DNS (UDP)
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "DNS UDP"
  }

  # LDAP
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "LDAP"
  }

  # LDAPS
  ingress {
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "LDAPS"
  }

  # Kerberos
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Kerberos TCP"
  }

  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Kerberos UDP"
  }

  # ICMP (ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP ping"
  }

  # WinRM for Ansible
  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "WinRM for Ansible"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "DC-Server-SG"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security Group for RDS (if enabled)
resource "aws_security_group" "rds_sg" {
  count       = var.create_rds ? 1 : 0
  name_prefix = "dc-rds-"
  description = "Security group for RDS database"
  vpc_id      = data.aws_vpc.default.id

  # SQL Server access from DC
  ingress {
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_security_group.dc_server_sg.id]
    description     = "SQL Server access from DC"
  }

  tags = {
    Name        = "DC-RDS-SG"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create Key Pair
resource "aws_key_pair" "dc_automation_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = {
    Name        = "DC-Automation-Key"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Minimal UserData script - only enables WinRM for Ansible
locals {
  userdata_script = <<-EOF
    <powershell>
    # Create log directory first
    New-Item -Path "C:\Logs" -ItemType Directory -Force
    
    # Start logging
    Start-Transcript -Path "C:\Logs\userdata.log" -Append
    
    Write-Host "Starting WinRM configuration for Ansible..."
    
    # Enable WinRM
    Enable-PSRemoting -Force
    
    # Configure WinRM for Ansible
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    Set-Item WSMan:\localhost\MaxTimeoutms -Value 1800000 -Force
    
    # Configure firewall for WinRM
    netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in action=allow protocol=TCP localport=5985
    netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in action=allow protocol=TCP localport=5986
    
    # Also try to modify existing rules if they exist
    try {
        Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress Any -ErrorAction SilentlyContinue
        Set-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -RemoteAddress Any -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Existing firewall rules not found, new rules created instead"
    }
    
    # Set execution policy
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
    
    # Restart WinRM service
    Restart-Service WinRM -Force
    
    # Verify WinRM is running
    $winrmStatus = Get-Service WinRM
    Write-Host "WinRM Service Status: $($winrmStatus.Status)"
    
    # Test WinRM locally
    try {
        Test-WSMan -ComputerName localhost
        Write-Host "WinRM test successful"
    } catch {
        Write-Host "WinRM test failed: $_"
    }
    
    Write-Host "WinRM configuration completed at $(Get-Date)"
    Stop-Transcript
    </powershell>
    <persist>true</persist>
  EOF
}

# Create EC2 Instance for Domain Controller
resource "aws_instance" "dc_server" {
  ami                    = data.aws_ami.windows_server_2016.id
  instance_type          = var.instance_type
  key_name              = aws_key_pair.dc_automation_key.key_name
  vpc_security_group_ids = [aws_security_group.dc_server_sg.id]
  subnet_id             = data.aws_subnets.default.ids[0]
  
  user_data = base64encode(local.userdata_script)

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    
    tags = {
      Name = "DC-Server-Root-Volume"
    }
  }

  tags = {
    Name        = "DC01-Server"
    Project     = "DC-Automation"
    Environment = var.environment
    Purpose     = "Domain Controller"
    ManagedBy   = "Terraform"
    AnsibleGroup = "domain_controllers"
  }
}

# Create Elastic IP (optional)
resource "aws_eip" "dc_server_eip" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.dc_server.id
  domain   = "vpc"

  tags = {
    Name        = "DC-Server-EIP"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_instance.dc_server]
}

# RDS Subnet Group (if RDS enabled)
resource "aws_db_subnet_group" "dc_rds_subnet_group" {
  count      = var.create_rds ? 1 : 0
  name       = "dc-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "DC-RDS-Subnet-Group"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# RDS Instance (optional)
resource "aws_db_instance" "dc_database" {
  count = var.create_rds ? 1 : 0

  identifier = "dc-automation-db"
  
  # Engine configuration
  engine         = "sqlserver-ex"
  engine_version = "15.00.4073.23.v1"
  instance_class = var.rds_instance_class
  
  # Storage
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type         = "gp2"
  storage_encrypted    = true
  
  # Database configuration
  db_name  = var.rds_database_name
  username = var.rds_username
  password = var.rds_password
  
  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.dc_rds_subnet_group[0].name
  vpc_security_group_ids = [aws_security_group.rds_sg[0].id]
  publicly_accessible    = false
  
  # Backup configuration
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring[0].arn
  
  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment == "prod" ? false : true
  
  tags = {
    Name        = "DC-Automation-Database"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM Role for RDS Enhanced Monitoring (if RDS enabled)
resource "aws_iam_role" "rds_monitoring" {
  count = var.create_rds ? 1 : 0
  name  = "dc-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "DC-RDS-Monitoring-Role"
    Project     = "DC-Automation"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.create_rds ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    dc_server_ip = var.use_elastic_ip ? aws_eip.dc_server_eip[0].public_ip : aws_instance.dc_server.public_ip
    server_name  = var.server_name
    domain_name  = var.domain_name
    rds_endpoint = var.create_rds ? aws_db_instance.dc_database[0].endpoint : ""
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"

  depends_on = [aws_instance.dc_server]
}
