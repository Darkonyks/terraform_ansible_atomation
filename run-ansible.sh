#!/bin/bash
# Run Ansible Playbook
# Usage: ./run-ansible.sh [options]
# Options:
#   --tags <tags>        Run only tasks with specific tags
#   --skip-tags <tags>   Skip tasks with specific tags
#   --check              Run in check mode (dry-run)
#   -v, -vv, -vvv        Verbosity level

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set locale
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

# Set Ansible roles path
export ANSIBLE_ROLES_PATH="$ANSIBLE_DIR/roles"

echo -e "${CYAN}========================================"
echo -e "  Running Ansible Playbook"
echo -e "========================================${NC}"
echo ""

# Change to ansible directory
cd "$ANSIBLE_DIR"

# Build command
CMD="ansible-playbook -i inventory/hosts.yml playbooks/site.yml"

# Parse arguments
VERBOSITY="-v"
while [[ $# -gt 0 ]]; do
    case $1 in
        --tags)
            CMD="$CMD --tags $2"
            shift 2
            ;;
        --skip-tags)
            CMD="$CMD --skip-tags $2"
            shift 2
            ;;
        --check)
            CMD="$CMD --check"
            shift
            ;;
        -v|-vv|-vvv)
            VERBOSITY="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

CMD="$CMD $VERBOSITY"

echo -e "${YELLOW}Command: $CMD${NC}"
echo ""
echo -e "${GREEN}Starting Ansible playbook execution...${NC}"
echo -e "${YELLOW}This may take 25-40 minutes for a full run.${NC}"
echo ""

# Run ansible-playbook with retry logic
MAX_RETRIES=2
RETRY_COUNT=0

while [ $RETRY_COUNT -le $MAX_RETRIES ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}========================================"
        echo -e "  Retrying playbook (attempt $((RETRY_COUNT + 1))/$((MAX_RETRIES + 1)))..."
        echo -e "  Waiting 30 seconds for system to stabilize..."
        echo -e "========================================${NC}"
        sleep 30
    fi
    
    # Run the playbook
    $CMD
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================"
        echo -e "  Ansible Playbook Completed!"
        echo -e "========================================${NC}"
        exit 0
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -le $MAX_RETRIES ]; then
            echo -e "${YELLOW}Playbook failed, will retry...${NC}"
        fi
    fi
done

echo ""
echo -e "${RED}========================================"
echo -e "  Ansible Playbook Failed after $((MAX_RETRIES + 1)) attempts!"
echo -e "========================================${NC}"
exit 1
