# 🚀 DC Automation - Complete Setup Guide

**Automated Windows Server 2016 Domain Controller deployment on AWS EC2 using Terraform and Ansible**

Author: Darko Nedic  
Version: 1.0  
Date: November 2025

---

## Table of Contents

1. [WSL Installation on Windows](#1-wsl-installation-on-windows)
2. [Terraform Installation in WSL](#2-terraform-installation-in-wsl)
3. [Ansible Installation in WSL](#3-ansible-installation-in-wsl)
4. [AWS Credentials Setup](#4-aws-credentials-setup)
5. [Terraform Files Structure](#5-terraform-files-structure)
6. [Ansible Files Structure](#6-ansible-files-structure)
7. [Deployment - Python Script](#7-deployment---python-script)
8. [Deployment - Manual (Terraform + Ansible)](#8-deployment---manual-terraform--ansible)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. WSL Installation on Windows

### 1.1 Install WSL

```powershell
# Open PowerShell as Administrator

# Install WSL with Fedora distribution
wsl --install -d Fedora-42

# Restart computer if required
```

### 1.2 Configure Fedora WSL

```bash
# After first launch, create username and password

# Update system
sudo dnf update -y

# Install basic tools
sudo dnf install -y git curl unzip less vim
```

---

## 2. Terraform Installation in WSL

### 2.1 Download and Install

```bash
# Download Terraform
cd /tmp
curl -O https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip

# Install unzip if not installed
sudo dnf install unzip -y

# Unzip
unzip terraform_1.9.8_linux_amd64.zip

# Move to /usr/local/bin
sudo mv terraform /usr/local/bin/

# Add execute permissions
sudo chmod +x /usr/local/bin/terraform

# Verify installation
terraform --version
```

Expected output:
```
Terraform v1.9.8
```

---

## 3. Ansible Installation in WSL

### 3.1 Install Ansible

```bash
# Install Python and pip
sudo dnf install -y python3 python3-pip

# Install Ansible
pip3 install --user ansible

# Install pywinrm for Windows connection
pip3 install --user pywinrm

# Add ~/.local/bin to PATH
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
ansible --version
```

### 3.2 Install Ansible Collections

```bash
# Install required collections
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install community.windows
```

---

## 4. AWS Credentials Setup

### 4.1 Create Access Key in AWS Console

1. **Log in to AWS Console:**
   ```
   https://console.aws.amazon.com/
   ```

2. **Go to IAM:**
   - Click on your name (top right)
   - Click **"Security credentials"**

3. **Create Access Key:**
   - Scroll down to "Access keys"
   - Click **"Create access key"**
   - Select use case: **"Command Line Interface (CLI)"**
   - Confirm checkbox "I understand..."
   - Click **"Create access key"**
   - **SAVE Access Key ID and Secret Access Key** (won't be shown again!)

### 4.2 Configure AWS CLI in WSL

```bash
# Install AWS CLI
sudo dnf install -y awscli

# Configure credentials
aws configure

# Enter:
# AWS Access Key ID: [your Access Key ID]
# AWS Secret Access Key: [your Secret Access Key]
# Default region name: us-east-1
# Default output format: json

# Disable pager (optional)
echo 'export AWS_PAGER=""' >> ~/.bashrc
source ~/.bashrc

# Verify configuration
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## 5. Terraform Files Structure

### 5.1 Structure Overview

```
terraform/
├── main.tf                 # Main file with resources
├── variables.tf            # Variable definitions
├── outputs.tf              # Output values
├── terraform.tfvars        # Variable values (gitignored)
├── terraform.tfvars.example # Configuration example
└── templates/
    └── inventory.tpl       # Template for Ansible inventory
```

### 5.2 Key Files Description

#### **main.tf**
Defines AWS resources:
- **VPC and Subnet** - Network for EC2 instance
- **Security Group** - Firewall rules (RDP, WinRM, HTTP, HTTPS, DNS, AD)
- **EC2 Instance** - Windows Server 2016 with UserData script for WinRM
- **Elastic IP** (optional) - Static IP address
- **RDS Instance** (optional) - SQL Server database
- **Local File** - Generates Ansible inventory file

#### **variables.tf**
Defines all variables used:
- `aws_region` - AWS region (default: us-east-1)
- `environment` - Environment (dev/prod)
- `instance_type` - EC2 instance type (default: t3a.medium)
- `server_name` - Server name (default: DC01)
- `domain_name` - AD domain (default: corp.local)
- `use_elastic_ip` - Whether to use Elastic IP
- `create_rds` - Whether to create RDS instance

#### **outputs.tf**
Defines output values after deployment:
- `instance_id` - EC2 instance ID
- `instance_public_ip` - Public IP address
- `instance_private_ip` - Private IP address
- `security_group_id` - Security Group ID
- `rdp_connection` - RDP connection string

#### **terraform.tfvars**
Contains specific variable values:
```hcl
environment     = "dev"
aws_region      = "us-east-1"
instance_type   = "t3a.medium"
server_name     = "DC01"
domain_name     = "corp.local"
use_elastic_ip  = false
create_rds      = false
```

---

## 6. Ansible Files Structure

### 6.1 Structure Overview

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   └── hosts.yml                  # Inventory file (generated by Terraform)
├── group_vars/
│   └── all.yml                    # Global variables
├── playbooks/
│   └── site.yml                   # Main playbook
└── roles/
    ├── common/                    # Basic configuration
    ├── domain_controller/         # DC installation
    ├── active_directory/          # AD structure
    ├── iis_webserver/             # IIS installation
    └── security/                  # Security configuration
```

### 6.2 Key Files Description

#### **ansible.cfg**
Ansible configuration:
- Defines inventory path
- Sets WinRM timeouts
- Configures logging
- Defines roles path

#### **inventory/hosts.yml**
Inventory file generated by Terraform:
- Defines host (DC01) with IP address
- WinRM connection parameters
- Server configuration (name, domain)
- Organizational Units (OUs)
- Users
- IIS features
- Firewall rules

#### **group_vars/all.yml**
Global variables for all hosts:
- Default passwords
- Timeouts
- Logging settings
- Windows Update settings

#### **playbooks/site.yml**
Main playbook orchestrating deployment:
- Pre-tasks: Create log directory
- Roles: common, domain_controller, active_directory, iis_webserver, security
- Post-tasks: Logging and completion messages

### 6.3 Ansible Roles

#### **common**
Basic server configuration:
- PowerShell execution policy
- Create automation directories
- Windows Updates
- Time service (UTC)
- Disable Windows Defender
- Event log sizes

#### **domain_controller**
Domain Controller installation and promotion:
- Rename server
- Install AD DS and DNS
- Promote to DC
- Create forest and domain
- Verify DC status

#### **active_directory**
Create AD structure:
- Create Organizational Units (Sales, IT, HR)
- Create domain users
- Add users to groups
- Configure password policy

#### **iis_webserver**
IIS installation and configuration:
- Install IIS Web Server
- Create custom HTML page
- Configure application pool
- Verify installation

#### **security**
Security and firewall configuration:
- Windows Firewall rules
- Audit policies
- Password policy
- Account lockout policy
- Disable unnecessary services

---

## 7. Deployment - Python Script

### 7.1 Automated Deployment (Recommended)

```bash
# Navigate to project
cd /mnt/d/DCAutomation

# Full automation (Terraform + Ansible)
python deploy.py deploy

# With custom parameters
python deploy.py deploy --environment prod --instance-type t3a.large --elastic-ip

# Terraform only (without Ansible)
python deploy.py deploy --skip-ansible

# Ansible only (server already exists)
python deploy.py ansible-only

# Destroy infrastructure
python deploy.py destroy

# Without confirmation (for CI/CD)
python deploy.py deploy --force
```

### 7.2 What Python Script Does Automatically

1. **Check prerequisites:**
   - Terraform installed
   - Ansible installed
   - AWS credentials configured
   - SSH key exists (or generates new one)

2. **Terraform deployment:**
   - `terraform init`
   - `terraform plan`
   - `terraform apply`
   - Gets instance IP and ID

3. **Wait for server:**
   - Tests WinRM connection (port 5985)
   - Waits up to 20 attempts (10 minutes)

4. **Get password:**
   - `aws ec2 get-password-data`
   - Automatically updates `hosts.yml`

5. **Ansible deployment:**
   - Runs `ansible-playbook`
   - Configures server completely

6. **Completion:**
   - Shows RDP connection string
   - Shows IIS URL
   - Shows Administrator password

---

## 8. Deployment - Manual (Terraform + Ansible)

### 8.1 Terraform Deployment

```bash
# 1. Navigate to terraform directory
cd /mnt/d/DCAutomation/terraform

# 2. Initialize Terraform
terraform init

# 3. Create terraform.tfvars (or copy from example)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit values

# 4. Plan deployment
terraform plan -out=tfplan

# 5. Apply deployment
terraform apply tfplan

# 6. Get output values
terraform output

# Specific outputs
terraform output -raw instance_public_ip
terraform output -raw instance_id
```

### 8.2 Get Windows Password

```bash
# Get Instance ID
INSTANCE_ID=$(terraform output -raw instance_id)

# Get password
aws ec2 get-password-data \
  --instance-id $INSTANCE_ID \
  --priv-launch-key dc-automation-key \
  --region us-east-1 \
  --query 'PasswordData' \
  --output text

# Save password to variable
PASSWORD=$(aws ec2 get-password-data \
  --instance-id $INSTANCE_ID \
  --priv-launch-key dc-automation-key \
  --region us-east-1 \
  --query 'PasswordData' \
  --output text)

echo "Administrator Password: $PASSWORD"
```

### 8.3 Update Ansible Inventory

```bash
# Get IP address
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Update hosts.yml with IP and password
cd ../ansible
vim inventory/hosts.yml

# Edit:
# ansible_host: [INSTANCE_IP]
# ansible_password: "[PASSWORD]"
```

### 8.4 Wait for WinRM

```bash
# Check if WinRM port is open
nc -zv $INSTANCE_IP 5985

# Or use Ansible ping
ansible -i inventory/hosts.yml DC01 -m win_ping

# Wait until available (may take 5-10 minutes)
```

### 8.5 Ansible Deployment

```bash
# Navigate to ansible directory
cd /mnt/d/DCAutomation/ansible

# Set ANSIBLE_ROLES_PATH
export ANSIBLE_ROLES_PATH=/mnt/d/DCAutomation/ansible/roles

# Run playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -v

# Or with specific tags
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common -v
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags domain_controller -v
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags iis -v
```

### 8.6 Destroy Infrastructure

```bash
# Navigate to terraform directory
cd /mnt/d/DCAutomation/terraform

# Destroy all resources
terraform destroy -auto-approve
```

---

## 9. Troubleshooting

### 9.1 Terraform Issues

**Problem: Terraform not found**
```bash
# Check installation
terraform --version

# Reinstall if needed
cd /tmp
curl -O https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Problem: AWS credentials not configured**
```bash
# Reconfigure
aws configure

# Verify
aws sts get-caller-identity
```

**Problem: SSH key not found**
```bash
# Generate SSH key
cd /mnt/d/DCAutomation/terraform
ssh-keygen -t rsa -b 4096 -f dc-automation-key -N ""
```

### 9.2 Ansible Issues

**Problem: Ansible not found**
```bash
# Install Ansible
pip3 install --user ansible pywinrm

# Add to PATH
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc
```

**Problem: WinRM connection timeout**
```bash
# Check if port is open
nc -zv [INSTANCE_IP] 5985

# Check Security Group in AWS Console
# Port 5985 (WinRM HTTP) must be open

# Wait longer - server may need 10-15 minutes to be ready
```

**Problem: Roles not found**
```bash
# Set ANSIBLE_ROLES_PATH
export ANSIBLE_ROLES_PATH=/mnt/d/DCAutomation/ansible/roles

# Or add to ansible.cfg
vim ansible.cfg
# roles_path = /mnt/d/DCAutomation/ansible/roles
```

**Problem: gather_facts timeout**
```bash
# gather_facts is already disabled in playbook
# If you have issues, increase timeout in inventory:
# ansible_winrm_operation_timeout_sec: 300
# ansible_winrm_read_timeout_sec: 360
```

### 9.3 AWS Issues

**Problem: Instance not starting**
```bash
# Check status in AWS Console
aws ec2 describe-instances --instance-ids [INSTANCE_ID]

# Check System Log
aws ec2 get-console-output --instance-id [INSTANCE_ID]
```

**Problem: Cannot get password**
```bash
# Wait 5-10 minutes after instance starts
# Password is available only after Windows fully boots

# Verify you're using correct key
aws ec2 get-password-data \
  --instance-id [INSTANCE_ID] \
  --priv-launch-key terraform/dc-automation-key
```

---

## Expected Duration

```
Terraform deployment:        2-3 minutes
Instance boot + WinRM:       5-10 minutes
Ansible - Common role:       2-3 minutes
Ansible - DC role:           10-15 minutes
Ansible - AD role:           3-5 minutes
Ansible - IIS role:          2-3 minutes
Ansible - Security role:     2-3 minutes
─────────────────────────────────────
TOTAL:                       25-40 minutes
```

---

## Final Result

After successful deployment you will have:

**Windows Server 2016** on AWS EC2  
**Active Directory Domain Controller** (corp.local)  
**DNS Server** configured  
**Organizational Units:** Sales, IT, HR  
**Domain Users:** SalesUser1-3, ITUser1-3, HRUser1-3, DomainAdmin  
**IIS Web Server** with custom Hello World page  
**Windows Firewall** configured  
**Security Policies** applied  
**Audit Logging** enabled  

---

## Server Access

```
RDP:     [INSTANCE_IP]:3389
IIS:     http://[INSTANCE_IP]
User:    Administrator
Pass:    [Retrieved from AWS]
Domain:  corp.local
```

---

## Logs

All logs are located on the server in `C:\Logs\`:
- `ansible-build.log` - Main deployment log
- `ad_structure.txt` - AD structure
- `iis_status.txt` - IIS status
- `security_config.txt` - Security configuration

---

**End of guide! Happy deployment! **
