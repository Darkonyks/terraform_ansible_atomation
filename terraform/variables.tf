# Variables for DC Automation Terraform + Ansible Configuration

# AWS Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for Domain Controller"
  type        = string
  default     = "t3a.medium"
  
  validation {
    condition = contains([
      "t3a.medium", "t3a.large", "t3a.xlarge",
      "t3.medium", "t3.large", "t3.xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.instance_type)
    error_message = "Instance type must be suitable for Domain Controller workload."
  }
}

# Key Pair Configuration
variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "dc-automation-key"
}

variable "public_key_path" {
  description = "Path to the public key file"
  type        = string
  default     = "./dc-automation-key.pub"
}

# Environment Configuration
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

# Server Configuration
variable "server_name" {
  description = "Windows server name"
  type        = string
  default     = "DC01"
  
  validation {
    condition     = length(var.server_name) <= 15
    error_message = "Server name must be 15 characters or less."
  }
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "corp.local"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN format."
  }
}

# Storage Configuration
variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 50
  
  validation {
    condition     = var.root_volume_size >= 40
    error_message = "Root volume size must be at least 40 GB for Domain Controller."
  }
}

# Network Configuration
variable "use_elastic_ip" {
  description = "Whether to create and assign an Elastic IP"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for RDP and WinRM access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# RDS Configuration
variable "create_rds" {
  description = "Whether to create RDS SQL Server instance"
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
  
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium",
      "db.t3.large", "db.m5.large", "db.m5.xlarge"
    ], var.rds_instance_class)
    error_message = "RDS instance class must be valid for SQL Server Express."
  }
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage for RDS in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.rds_allocated_storage >= 20
    error_message = "RDS allocated storage must be at least 20 GB."
  }
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for RDS auto-scaling in GB"
  type        = number
  default     = 100
}

variable "rds_database_name" {
  description = "Name of the initial database"
  type        = string
  default     = "DCAutomation"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_username" {
  description = "Master username for RDS instance"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "rds_password" {
  description = "Master password for RDS instance"
  type        = string
  default     = "DBPassword123!"
  sensitive   = true
  
  validation {
    condition     = length(var.rds_password) >= 8
    error_message = "RDS password must be at least 8 characters long."
  }
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}
