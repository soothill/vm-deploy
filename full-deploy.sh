#!/bin/bash
#
# Copyright (c) 2025 Darren Soothill
# Email: darren [at] soothill [dot] com
# License: MIT
set -e

# Complete OpenSUSE Ceph Cluster Deployment Script
# This script handles the entire deployment from start to finish

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "OpenSUSE Ceph Cluster Deployment"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    print_error "Ansible not found. Please install Ansible first."
    exit 1
fi

print_status "Ansible found"

# Check if configuration exists
if [ ! -f "${SCRIPT_DIR}/vars/vm_config.yml" ]; then
    print_error "Configuration file not found: vars/vm_config.yml"
    exit 1
fi

print_status "Configuration file found"

# Check if inventory exists
if [ ! -f "${SCRIPT_DIR}/inventory.ini" ]; then
    print_error "Inventory file not found: inventory.ini"
    exit 1
fi

print_status "Inventory file found"

echo ""
echo "========================================"
echo "Deployment Steps"
echo "========================================"
echo "1. Deploy VMs on Proxmox (2-5 min)"
echo "2. Wait for VMs to be ready"
echo "3. Configure VMs (GitHub keys, updates, services)"
echo ""
echo "Prerequisites:"
echo "- OpenSUSE image built on Proxmox host"
echo "- vars/vm_config.yml configured"
echo "- inventory.ini updated with Proxmox host"
echo "- inventory-vms.ini updated with VM IPs"
echo ""

read -p "Ready to proceed? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "========================================"
echo "Step 1: Deploying VMs on Proxmox"
echo "========================================"

if ansible-playbook -i inventory.ini deploy-vms.yml; then
    print_status "VMs deployed successfully"
else
    print_error "VM deployment failed"
    exit 1
fi

echo ""
echo "========================================"
echo "Step 2: Waiting for VMs to be ready"
echo "========================================"
print_warning "Waiting 30 seconds for VMs to fully boot..."
sleep 30

echo ""
echo "========================================"
echo "Step 3: Configuring VMs"
echo "========================================"
echo ""
print_warning "This step will:"
echo "  - Import GitHub SSH keys (if configured)"
echo "  - Update all packages"
echo "  - Verify avahi-daemon is running"
echo "  - Verify lldpd is running"
echo "  - Check data disks"
echo ""

if [ ! -f "${SCRIPT_DIR}/inventory-vms.ini" ]; then
    print_error "VM inventory not found: inventory-vms.ini"
    print_warning "Please update inventory-vms.ini with VM IP addresses and run:"
    echo "  ansible-playbook -i inventory-vms.ini configure-vms.yml"
    exit 1
fi

read -p "Continue with VM configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Skipping VM configuration. Run manually with:"
    echo "  ansible-playbook -i inventory-vms.ini configure-vms.yml"
    exit 0
fi

if ansible-playbook -i inventory-vms.ini configure-vms.yml; then
    print_status "VM configuration completed"
else
    print_error "VM configuration failed"
    print_warning "You can retry with:"
    echo "  ansible-playbook -i inventory-vms.ini configure-vms.yml"
    exit 1
fi

echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
print_status "All VMs deployed and configured"
echo ""
echo "Next steps:"
echo "  1. Verify VMs are accessible: ssh root@<vm-ip>"
echo "  2. Check LLDP neighbors: lldpcli show neighbors"
echo "  3. Check Avahi services: avahi-browse -a"
echo "  4. Verify data disks: lsblk"
echo "  5. Deploy Ceph OSDs on data disks"
echo ""
echo "Data disks (unformatted, ready for Ceph):"
echo "  /dev/sdb (1TB)"
echo "  /dev/sdc (1TB)"
echo "  /dev/sdd (1TB)"
echo "  /dev/sde (1TB)"
echo ""
echo "For Ceph deployment, use:"
echo "  ceph orch daemon add osd <hostname>:/dev/sd[bcde]"
echo ""
print_status "Cluster is ready for Ceph deployment!"
