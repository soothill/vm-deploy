#!/bin/bash
# Generate vm_config.yml from environment variables
#
# Copyright (c) 2025 Darren Soothill
# Email: darren [at] soothill [dot] com
# License: MIT

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/vars/vm_config.yml"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Generating VM Configuration from Environment Variables"
echo "========================================"
echo ""

# Check if .env exists and source it
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✓${NC} Found .env file, sourcing..."
    source "$ENV_FILE"
else
    echo -e "${YELLOW}!${NC} No .env file found. Using existing environment variables or defaults."
    echo "  Create one from: cp .env.example .env"
fi

# Set defaults if not set
PROXMOX_API_USER="${PROXMOX_API_USER:-root@pam}"
PROXMOX_API_PASSWORD="${PROXMOX_API_PASSWORD:-your_password_here}"
PROXMOX_API_HOST="${PROXMOX_API_HOST:-proxmox.example.com}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
OPENSUSE_IMAGE_PATH="${OPENSUSE_IMAGE_PATH:-/var/lib/vz/template/iso/opensuse-leap-custom.qcow2}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
STORAGE_POOL="${STORAGE_POOL:-nvme-pool}"
DATA_DISK_SIZE="${DATA_DISK_SIZE:-1000G}"
MON_DISK_SIZE="${MON_DISK_SIZE:-100G}"
PRIVATE_BRIDGE="${PRIVATE_BRIDGE:-vmbr1}"
PUBLIC_BRIDGE="${PUBLIC_BRIDGE:-vmbr0}"
VM_DEFAULT_MEMORY="${VM_DEFAULT_MEMORY:-32768}"
VM_DEFAULT_CORES="${VM_DEFAULT_CORES:-8}"
VM_DEFAULT_SOCKETS="${VM_DEFAULT_SOCKETS:-1}"
VM_CPU_TYPE="${VM_CPU_TYPE:-host}"
AUTO_START="${AUTO_START:-true}"
VM_ROOT_PASSWORD="${VM_ROOT_PASSWORD:-opensuse}"
NUM_VMS="${NUM_VMS:-4}"

# VM defaults
VM1_NAME="${VM1_NAME:-ceph-node1}"
VM1_VMID="${VM1_VMID:-200}"
VM1_MEMORY="${VM1_MEMORY:-$VM_DEFAULT_MEMORY}"
VM1_CORES="${VM1_CORES:-$VM_DEFAULT_CORES}"
VM1_SOCKETS="${VM1_SOCKETS:-$VM_DEFAULT_SOCKETS}"
VM1_ONBOOT="${VM1_ONBOOT:-1}"
VM1_IP="${VM1_IP:-192.168.1.10}"

VM2_NAME="${VM2_NAME:-ceph-node2}"
VM2_VMID="${VM2_VMID:-201}"
VM2_MEMORY="${VM2_MEMORY:-$VM_DEFAULT_MEMORY}"
VM2_CORES="${VM2_CORES:-$VM_DEFAULT_CORES}"
VM2_SOCKETS="${VM2_SOCKETS:-$VM_DEFAULT_SOCKETS}"
VM2_ONBOOT="${VM2_ONBOOT:-1}"
VM2_IP="${VM2_IP:-192.168.1.11}"

VM3_NAME="${VM3_NAME:-ceph-node3}"
VM3_VMID="${VM3_VMID:-202}"
VM3_MEMORY="${VM3_MEMORY:-$VM_DEFAULT_MEMORY}"
VM3_CORES="${VM3_CORES:-$VM_DEFAULT_CORES}"
VM3_SOCKETS="${VM3_SOCKETS:-$VM_DEFAULT_SOCKETS}"
VM3_ONBOOT="${VM3_ONBOOT:-1}"
VM3_IP="${VM3_IP:-192.168.1.12}"

VM4_NAME="${VM4_NAME:-ceph-node4}"
VM4_VMID="${VM4_VMID:-203}"
VM4_MEMORY="${VM4_MEMORY:-$VM_DEFAULT_MEMORY}"
VM4_CORES="${VM4_CORES:-$VM_DEFAULT_CORES}"
VM4_SOCKETS="${VM4_SOCKETS:-$VM_DEFAULT_SOCKETS}"
VM4_ONBOOT="${VM4_ONBOOT:-1}"
VM4_IP="${VM4_IP:-192.168.1.13}"

echo "Configuration:"
echo "  Proxmox Host: $PROXMOX_API_HOST"
echo "  Storage Pool: $STORAGE_POOL"
echo "  Data Disk Size: $DATA_DISK_SIZE"
echo "  Mon Disk Size: $MON_DISK_SIZE"
echo "  Default Memory: $VM_DEFAULT_MEMORY MB"
echo "  Default Cores: $VM_DEFAULT_CORES"
echo "  GitHub User: ${GITHUB_USERNAME:-'(not set)'}"
echo "  Number of VMs: $NUM_VMS"
echo ""

# Generate YAML file
cat > "$OUTPUT_FILE" << EOF
---
# Generated from environment variables on $(date)
# To regenerate: ./generate-config.sh

# Proxmox API Configuration
proxmox_api_user: "$PROXMOX_API_USER"
proxmox_api_password: "$PROXMOX_API_PASSWORD"
proxmox_api_host: "$PROXMOX_API_HOST"
proxmox_node: "$PROXMOX_NODE"

# OpenSUSE Image Configuration
opensuse_image_path: "$OPENSUSE_IMAGE_PATH"

# GitHub SSH Key Configuration
github_username: "$GITHUB_USERNAME"

# VM Root Password
vm_root_password: "$VM_ROOT_PASSWORD"

# Storage Configuration - Single NVMe Pool
storage_pool: "$STORAGE_POOL"
data_disk_size: "$DATA_DISK_SIZE"
mon_disk_size: "$MON_DISK_SIZE"

# Network Configuration
private_bridge: "$PRIVATE_BRIDGE"
public_bridge: "$PUBLIC_BRIDGE"

# VM Default Settings
vm_default_memory: $VM_DEFAULT_MEMORY
vm_default_cores: $VM_DEFAULT_CORES
vm_default_sockets: $VM_DEFAULT_SOCKETS
vm_cpu_type: "$VM_CPU_TYPE"

# Auto-start VMs after creation
auto_start: $AUTO_START

# VM Definitions
vms:
EOF

# Add VMs based on NUM_VMS
for i in $(seq 1 $NUM_VMS); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_VMID=\$VM${i}_VMID"
    eval "VM_MEMORY=\$VM${i}_MEMORY"
    eval "VM_CORES=\$VM${i}_CORES"
    eval "VM_SOCKETS=\$VM${i}_SOCKETS"
    eval "VM_ONBOOT=\$VM${i}_ONBOOT"
    eval "VM_IP=\$VM${i}_IP"
    
    cat >> "$OUTPUT_FILE" << EOF
  - name: "$VM_NAME"
    vmid: $VM_VMID
    memory: $VM_MEMORY
    cores: $VM_CORES
    sockets: $VM_SOCKETS
    onboot: $VM_ONBOOT
    ip: "$VM_IP"
EOF

    if [ $i -lt $NUM_VMS ]; then
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo -e "${GREEN}✓${NC} Configuration file generated: $OUTPUT_FILE"
echo ""
echo "VM Configuration:"
for i in $(seq 1 $NUM_VMS); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_MEMORY=\$VM${i}_MEMORY"
    eval "VM_CORES=\$VM${i}_CORES"
    echo "  - $VM_NAME: ${VM_MEMORY}MB RAM, ${VM_CORES} cores"
done
echo ""
echo "Ready to deploy! Run:"
echo "  ansible-playbook -i inventory.ini deploy-vms.yml"
