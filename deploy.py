#!/usr/bin/env python3
"""
DC Automation - Terraform + Ansible Deployment Script
Author: Darko Nedic
Version: 2.0
"""

import argparse
import subprocess
import sys
import time
import os
import json
from pathlib import Path
from datetime import datetime
import socket

# Color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def log(message, level="INFO"):
    """Print formatted log message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    colors = {
        "INFO": Colors.OKBLUE,
        "SUCCESS": Colors.OKGREEN,
        "WARNING": Colors.WARNING,
        "ERROR": Colors.FAIL
    }
    color = colors.get(level, Colors.OKBLUE)
    print(f"{color}[{timestamp}] [{level}] {message}{Colors.ENDC}")

def banner(text):
    """Print banner"""
    print(f"\n{Colors.OKCYAN}{'=' * 64}")
    print(f"  {text}")
    print(f"{'=' * 64}{Colors.ENDC}\n")

def run_command(cmd, cwd=None, capture_output=False):
    """Run shell command"""
    try:
        if capture_output:
            result = subprocess.run(
                cmd, 
                shell=True, 
                cwd=cwd, 
                capture_output=True, 
                text=True,
                check=True
            )
            return result.stdout.strip()
        else:
            subprocess.run(cmd, shell=True, cwd=cwd, check=True)
            return None
    except subprocess.CalledProcessError as e:
        log(f"Command failed: {e}", "ERROR")
        sys.exit(1)

def check_prerequisites():
    """Check if required tools are installed"""
    log("Checking prerequisites...", "INFO")
    
    # Check Terraform
    try:
        version = run_command("terraform --version", capture_output=True)
        log(f"Terraform: {version.split()[1]}", "SUCCESS")
    except:
        log("Terraform not found! Please install Terraform.", "ERROR")
        sys.exit(1)
    
    # Check Ansible
    try:
        version = run_command("ansible --version", capture_output=True)
        log(f"Ansible: {version.split()[1]}", "SUCCESS")
    except:
        log("Ansible not found! Please install Ansible.", "ERROR")
        sys.exit(1)
    
    # Check AWS CLI
    try:
        run_command("aws sts get-caller-identity", capture_output=True)
        log("AWS credentials: Valid", "SUCCESS")
    except:
        log("AWS credentials not configured!", "ERROR")
        sys.exit(1)
    
    # Check SSH key
    key_path = Path("terraform/dc-automation-key")
    pub_key_path = Path("terraform/dc-automation-key.pub")
    
    if not key_path.exists() or not pub_key_path.exists():
        log("SSH key pair not found. Generating...", "WARNING")
        os.chdir("terraform")
        run_command('ssh-keygen -t rsa -b 4096 -f dc-automation-key -N ""')
        os.chdir("..")
        log("SSH key pair generated", "SUCCESS")

def test_winrm_connectivity(ip, port=5985, max_attempts=20):
    """Test WinRM connectivity"""
    log("=" * 60, "INFO")
    log(f"Waiting for Windows Server to boot and WinRM to be ready...", "INFO")
    log(f"Target: {ip}:{port}", "INFO")
    log(f"This may take 5-10 minutes...", "INFO")
    log("=" * 60, "INFO")
    
    for attempt in range(1, max_attempts + 1):
        elapsed_time = (attempt - 1) * 30
        log(f"[{elapsed_time}s] Attempt {attempt}/{max_attempts} - Testing WinRM connectivity...", "INFO")
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((ip, port))
            sock.close()
            
            if result == 0:
                log("", "SUCCESS")
                log("=" * 60, "SUCCESS")
                log("✓ WinRM is ready! Instance is accessible!", "SUCCESS")
                log("=" * 60, "SUCCESS")
                return True
            else:
                log(f"  → Port {port} not open yet, waiting 30 seconds...", "WARNING")
        except Exception as e:
            log(f"  → Connection test failed: {e}", "WARNING")
        
        if attempt < max_attempts:
            time.sleep(30)
    
    log("", "ERROR")
    log(f"✗ Instance not ready after {max_attempts} attempts ({max_attempts * 30}s).", "ERROR")
    return False

def deploy_infrastructure(args):
    """Deploy infrastructure with Terraform"""
    banner("PHASE 1: TERRAFORM INFRASTRUCTURE DEPLOYMENT")
    
    os.chdir("terraform")
    
    # Initialize Terraform
    log("Initializing Terraform...", "INFO")
    run_command("terraform init")
    
    # Create terraform.tfvars if it doesn't exist
    tfvars_path = Path("terraform.tfvars")
    if not tfvars_path.exists():
        log("Creating terraform.tfvars from example...", "INFO")
        
        with open("terraform.tfvars.example", "r") as f:
            tfvars_content = f.read()
        
        # Update values
        tfvars_content = tfvars_content.replace('environment = "dev"', f'environment = "{args.environment}"')
        tfvars_content = tfvars_content.replace('aws_region = "us-east-1"', f'aws_region = "{args.region}"')
        tfvars_content = tfvars_content.replace('instance_type = "t3a.medium"', f'instance_type = "{args.instance_type}"')
        tfvars_content = tfvars_content.replace('use_elastic_ip = false', f'use_elastic_ip = {str(args.elastic_ip).lower()}')
        tfvars_content = tfvars_content.replace('create_rds = false', f'create_rds = {str(args.create_rds).lower()}')
        
        with open("terraform.tfvars", "w") as f:
            f.write(tfvars_content)
        
        log("Please review and update terraform.tfvars with your values", "WARNING")
        if not args.force:
            input("Press Enter to continue after reviewing terraform.tfvars...")
    
    # Plan deployment
    log("Planning Terraform deployment...", "INFO")
    run_command("terraform plan -out=tfplan")
    
    if not args.force:
        confirm = input("Do you want to apply this plan? (y/N): ")
        if confirm.lower() != 'y':
            log("Deployment cancelled by user", "WARNING")
            sys.exit(0)
    
    # Apply deployment
    log("Applying Terraform deployment...", "INFO")
    run_command("terraform apply tfplan")
    
    # Get outputs
    instance_ip = run_command("terraform output -raw instance_public_ip", capture_output=True)
    instance_id = run_command("terraform output -raw instance_id", capture_output=True)
    
    log("Infrastructure deployed successfully!", "SUCCESS")
    log(f"Instance IP: {instance_ip}", "INFO")
    log(f"Instance ID: {instance_id}", "INFO")
    
    os.chdir("..")
    
    return instance_ip, instance_id

def configure_with_ansible(instance_ip, instance_id, args):
    """Configure server with Ansible"""
    banner("PHASE 2: WAITING FOR INSTANCE TO BE READY")
    
    if not test_winrm_connectivity(instance_ip):
        log("Instance not ready. You can run Ansible manually later.", "WARNING")
        log("Manual command: ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml", "INFO")
        return
    
    banner("PHASE 3: ANSIBLE CONFIGURATION")
    
    # Get Windows password
    log("Getting Windows Administrator password...", "INFO")
    try:
        password = run_command(
            f"aws ec2 get-password-data --instance-id {instance_id} "
            f"--priv-launch-key terraform/dc-automation-key --region {args.region} "
            f"--query 'PasswordData' --output text",
            capture_output=True
        )
        
        if password:
            log("Password retrieved successfully", "SUCCESS")
            
            # Update Ansible inventory with password and IP
            inventory_path = Path("ansible/inventory/hosts.yml")
            
            # Read file and use regex to update specific values only
            with open(inventory_path, "r") as f:
                content = f.read()
            
            import re
            # Update ansible_host (preserve indentation)
            content = re.sub(
                r'(^\s+ansible_host:\s+)[\d\.]+',
                f'\\g<1>{instance_ip}',
                content,
                flags=re.MULTILINE
            )
            
            # Update ansible_password (preserve indentation and quotes)
            content = re.sub(
                r'(^\s+ansible_password:\s+)"[^"]*"',
                f'\\g<1>"{password}"',
                content,
                flags=re.MULTILINE
            )
            
            # Write back
            with open(inventory_path, "w") as f:
                f.write(content)
            
            log(f"Updated inventory with IP: {instance_ip} and password", "SUCCESS")
            
            # Run Ansible playbook
            os.chdir("ansible")
            log("=" * 60, "INFO")
            log("STARTING ANSIBLE PLAYBOOK EXECUTION", "INFO")
            log("This will take 25-40 minutes to complete...", "INFO")
            log("=" * 60, "INFO")
            log("", "INFO")
            
            # Set ANSIBLE_ROLES_PATH environment variable
            env = os.environ.copy()
            env['ANSIBLE_ROLES_PATH'] = str(Path.cwd() / "roles")
            
            # Run playbook with retry logic
            log("Executing: ansible-playbook -i inventory/hosts.yml playbooks/site.yml -v", "INFO")
            log("", "INFO")
            
            max_retries = 2
            retry_count = 0
            success = False
            
            while retry_count <= max_retries and not success:
                if retry_count > 0:
                    log("", "WARNING")
                    log(f"Retrying playbook (attempt {retry_count + 1}/{max_retries + 1})...", "WARNING")
                    log("Waiting 30 seconds for system to stabilize...", "INFO")
                    time.sleep(30)
                
                result = subprocess.run(
                    "ansible-playbook -i inventory/hosts.yml playbooks/site.yml -v",
                    shell=True,
                    env=env
                )
                
                if result.returncode == 0:
                    success = True
                    log("", "INFO")
                    log("=" * 60, "SUCCESS")
                    log("ANSIBLE PLAYBOOK COMPLETED SUCCESSFULLY!", "SUCCESS")
                    log("=" * 60, "SUCCESS")
                else:
                    retry_count += 1
                    if retry_count <= max_retries:
                        log(f"Playbook failed, will retry...", "WARNING")
            
            os.chdir("..")
            
            if not success:
                log("", "ERROR")
                log(f"Ansible playbook failed after {max_retries + 1} attempts", "ERROR")
            
            banner("DEPLOYMENT COMPLETED SUCCESSFULLY!")
            log(f"RDP: {instance_ip}:3389", "INFO")
            log(f"IIS: http://{instance_ip}", "INFO")
            log(f"Administrator Password: {password}", "INFO")
        else:
            log("Could not retrieve password. Please get it manually:", "WARNING")
            log(f"aws ec2 get-password-data --instance-id {instance_id} "
                f"--priv-launch-key terraform/dc-automation-key --region {args.region}", "INFO")
    except Exception as e:
        log(f"Error retrieving password: {e}", "ERROR")

def destroy_infrastructure(args):
    """Destroy infrastructure"""
    banner("DESTROYING INFRASTRUCTURE")
    
    if not args.force:
        confirm = input("Are you sure you want to destroy all infrastructure? (y/N): ")
        if confirm.lower() != 'y':
            log("Destroy cancelled by user", "WARNING")
            sys.exit(0)
    
    os.chdir("terraform")
    run_command("terraform destroy -auto-approve")
    os.chdir("..")
    
    log("Infrastructure destroyed successfully!", "SUCCESS")

def ansible_only():
    """Run Ansible configuration only"""
    banner("RUNNING ANSIBLE CONFIGURATION ONLY")
    
    # Check if password exists in inventory
    inventory_path = Path("ansible/inventory/hosts.yml")
    with open(inventory_path, "r") as f:
        inventory = f.read()
    
    if 'ansible_password:' not in inventory:
        log("Password not found in inventory. Please run full deployment first.", "ERROR")
        log("Or manually add ansible_password to ansible/inventory/hosts.yml", "INFO")
        sys.exit(1)
    
    os.chdir("ansible")
    
    # Set ANSIBLE_ROLES_PATH environment variable
    env = os.environ.copy()
    env['ANSIBLE_ROLES_PATH'] = str(Path.cwd() / "roles")
    
    subprocess.run(
        "ansible-playbook -i inventory/hosts.yml playbooks/site.yml -v",
        shell=True,
        env=env
    )
    os.chdir("..")

def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description="DC Automation - Terraform + Ansible Deployment"
    )
    
    parser.add_argument(
        "action",
        choices=["deploy", "destroy", "ansible-only"],
        help="Action to perform"
    )
    
    parser.add_argument(
        "--environment",
        default="dev",
        help="Environment name (default: dev)"
    )
    
    parser.add_argument(
        "--region",
        default="us-east-1",
        help="AWS region (default: us-east-1)"
    )
    
    parser.add_argument(
        "--instance-type",
        default="t3a.medium",
        help="EC2 instance type (default: t3a.medium)"
    )
    
    parser.add_argument(
        "--elastic-ip",
        action="store_true",
        help="Use Elastic IP"
    )
    
    parser.add_argument(
        "--create-rds",
        action="store_true",
        help="Create RDS instance"
    )
    
    parser.add_argument(
        "--skip-ansible",
        action="store_true",
        help="Skip Ansible configuration"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Skip confirmation prompts"
    )
    
    args = parser.parse_args()
    
    banner("DC AUTOMATION - TERRAFORM + ANSIBLE DEPLOYMENT")
    
    check_prerequisites()
    
    if args.action == "deploy":
        instance_ip, instance_id = deploy_infrastructure(args)
        
        if not args.skip_ansible:
            configure_with_ansible(instance_ip, instance_id, args)
    
    elif args.action == "destroy":
        destroy_infrastructure(args)
    
    elif args.action == "ansible-only":
        ansible_only()
    
    log("Script completed!", "SUCCESS")

if __name__ == "__main__":
    main()
