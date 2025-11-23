# DC Automation - Terraform Deployment

**Automated Windows Server 2016 Domain Controller Infrastructure with Terraform**

Author: Darko Nedic  
Version: 1.0  
Date: November 2025

---

## Overview

This Terraform configuration automates the complete AWS infrastructure deployment for a Windows Server 2016 Domain Controller, including:

- EC2 instance with Windows Server 2016
- Security Group with proper firewall rules
- Key Pair for secure access
- Automated DC setup via UserData script
- Optional Elastic IP

---

## Prerequisites

### Local Machine:
1. **Terraform** installed (v1.0+)
2. **AWS CLI** configured or AWS credentials
3. **PowerShell 5.1+** (for AWS password retrieval)
4. **SSH key pair** generated

### AWS Account:
1. **AWS Account** with EC2 permissions
2. **VPC** with internet gateway (default VPC works)
3. **Appropriate IAM permissions** for EC2, VPC, and Key Pair operations

---

## Quick Start

### 1. Generate SSH Key Pair

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f dc-automation-key

# This creates:
# - dc-automation-key (private key)
# - dc-automation-key.pub (public key)
```

### 2. Configure AWS Credentials

```powershell
# Method 1: AWS CLI
aws configure

# Method 2: Environment Variables
$env:AWS_ACCESS_KEY_ID = "your-access-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-key"
$env:AWS_DEFAULT_REGION = "us-east-1"

# Method 3: PowerShell (if using AWS Tools)
Set-AWSCredential -AccessKey "your-access-key" -SecretKey "your-secret-key" -StoreAs default
```

### 3. Initialize Terraform

```powershell
# Navigate to terraform directory
cd D:\DCAutomation\terraform

# Initialize Terraform
terraform init
```

### 4. Configure Variables

```powershell
# Copy example variables file
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
notepad terraform.tfvars
```

### 5. Deploy Infrastructure

```powershell
# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply deployment
terraform apply
```

---

## Configuration

### Required Variables

Edit `terraform.tfvars` file:

```hcl
# AWS Configuration
aws_region    = "us-east-1"
instance_type = "t3a.medium"

# Key Pair (ensure public key file exists)
key_name        = "dc-automation-key"
public_key_path = "./dc-automation-key.pub"

# Server Configuration
server_name = "DC01"
domain_name = "corp.local"

# Security (CHANGE THESE!)
dsrm_password = "YourSecureDSRMPassword123!"
user_password = "YourSecureUserPassword123!"
```

### Optional Variables

```hcl
# Environment tag
environment = "dev"

# Storage
root_volume_size = 50

# Networking
use_elastic_ip = true
allowed_cidr_blocks = ["YOUR.IP.ADDRESS/32"]
```

---

## Deployment Process

### What Terraform Creates:

1. **Security Group** with rules for:
   - RDP (3389)
   - HTTP (80)
   - HTTPS (443)
   - ICMP (ping)

2. **Key Pair** from your public key

3. **EC2 Instance** with:
   - Latest Windows Server 2016 AMI
   - Encrypted EBS volume
   - UserData script for automation

4. **Optional Elastic IP** for static public IP

### Automated Setup Process:

1. **Phase 0**: Rename server → DC01 (reboot)
2. **Phase 1**: Install AD DS + Promote DC (reboot)
3. **Phase 2**: Create OUs + Users
4. **Phase 3**: Install IIS + Hello World page
5. **Phase 4**: Finalization + Cleanup

**Total Time**: 30-40 minutes

---

## Access and Management

### Get Instance Information

```powershell
# Get all outputs
terraform output

# Get specific values
terraform output instance_public_ip
terraform output rdp_connection
terraform output get_password_command
```

### Get Windows Password

```powershell
# Using Terraform output
terraform output powershell_get_password_command

# Manual command
Get-EC2PasswordData -InstanceId "i-xxxxx" -PemFile "./dc-automation-key.pem" -Region "us-east-1"
```

### Connect to Server

```powershell
# RDP connection
mstsc /v:$(terraform output -raw instance_public_ip):3389

# Or use the connection string
terraform output rdp_connection
```

### Test IIS

```powershell
# Get IIS URL
terraform output iis_url

# Test in browser or PowerShell
Invoke-WebRequest $(terraform output -raw iis_url)
```

---

## Monitoring and Logs

### Server Logs

```powershell
# After RDP to server, check logs:
Get-Content C:\Logs\terraform-build.log -Tail 20 -Wait

# Check current phase
Get-Content C:\Automation\state.json

# Check scheduled task
Get-ScheduledTask -TaskName "DCSetup-TerraformResume"
```

### Terraform State

```powershell
# Show current state
terraform show

# List resources
terraform state list

# Get resource details
terraform state show aws_instance.dc_server
```

---

## Cleanup

### Destroy Infrastructure

```powershell
# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=aws_instance.dc_server
```

### Clean Local Files

```powershell
# Remove Terraform state files
Remove-Item .terraform -Recurse -Force
Remove-Item terraform.tfstate*
Remove-Item .terraform.lock.hcl
```

---

## Troubleshooting

### Common Issues

1. **Key Pair Error**:
   ```
   Error: InvalidKeyPair.NotFound
   ```
   - Ensure `dc-automation-key.pub` exists
   - Check public key format

2. **Permission Denied**:
   ```
   Error: UnauthorizedOperation
   ```
   - Verify AWS credentials
   - Check IAM permissions

3. **Instance Launch Failed**:
   ```
   Error: InvalidAMIID.NotFound
   ```
   - Check AWS region
   - Verify AMI availability

### Debug Commands

```powershell
# Enable Terraform debug logging
$env:TF_LOG = "DEBUG"
terraform apply

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check

# Show plan in detail
terraform plan -detailed-exitcode
```

### Server Issues

```powershell
# If UserData script fails:
# 1. RDP to server
# 2. Check logs: C:\Logs\terraform-build.log
# 3. Manual resume: C:\Automation\terraform-resume.ps1

# If AD services fail:
Restart-Computer -Force
# Script will auto-resume

# If IIS fails:
Install-WindowsFeature Web-Server -Source wim:d:\sources\install.wim:4
```

---

## Security Considerations

### Best Practices

1. **Change Default Passwords**:
   ```hcl
   dsrm_password = "YourUniqueSecurePassword!"
   user_password = "AnotherUniquePassword!"
   ```

2. **Restrict RDP Access**:
   ```hcl
   allowed_cidr_blocks = ["YOUR.PUBLIC.IP/32"]
   ```

3. **Use Elastic IP** for production:
   ```hcl
   use_elastic_ip = true
   ```

4. **Enable EBS Encryption** (already configured):
   ```hcl
   encrypted = true
   ```

### Secrets Management

```powershell
# Use environment variables for sensitive data
$env:TF_VAR_dsrm_password = "SecurePassword123!"
$env:TF_VAR_user_password = "AnotherPassword123!"

# Then remove from terraform.tfvars file
```

---

## Advanced Usage

### Multiple Environments

```powershell
# Create environment-specific var files
terraform apply -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

### Custom AMI

```hcl
# Override AMI in variables
variable "custom_ami_id" {
  description = "Custom AMI ID to use instead of latest Windows Server 2016"
  type        = string
  default     = ""
}
```

### Additional Security Groups

```hcl
# Add existing security groups
vpc_security_group_ids = [
  aws_security_group.dc_automation_sg.id,
  "sg-existing-group-id"
]
```

---

## Support

For issues and questions:
- Check Terraform logs: `terraform apply -debug`
- Check server logs: `C:\Logs\terraform-build.log`
- Verify AWS permissions and quotas
- Contact: Darko Nedic

---

**Infrastructure as Code - Automated and Repeatable!**
