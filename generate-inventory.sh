#!/bin/bash
# Generate inventory files from environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXMOX_INVENTORY="${SCRIPT_DIR}/inventory.ini"
VMS_INVENTORY="${SCRIPT_DIR}/inventory-vms.ini"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Generating Inventory Files from Environment Variables"
echo "========================================"
echo ""

# Check if .env exists and source it
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✓${NC} Found .env file, sourcing..."
    source "$ENV_FILE"
else
    echo -e "${YELLOW}!${NC} No .env file found. Using existing environment variables or defaults."
fi

# Set defaults
PROXMOX_API_HOST="${PROXMOX_API_HOST:-proxmox.example.com}"
PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-root}"
PROXMOX_SSH_KEY="${PROXMOX_SSH_KEY:-~/.ssh/id_rsa}"
VM_SSH_USER="${VM_SSH_USER:-root}"
VM_ROOT_PASSWORD="${VM_ROOT_PASSWORD:-opensuse}"
NUM_VMS="${NUM_VMS:-4}"

# VM defaults
VM1_NAME="${VM1_NAME:-ceph-node1}"
VM1_IP="${VM1_IP:-192.168.1.10}"
VM2_NAME="${VM2_NAME:-ceph-node2}"
VM2_IP="${VM2_IP:-192.168.1.11}"
VM3_NAME="${VM3_NAME:-ceph-node3}"
VM3_IP="${VM3_IP:-192.168.1.12}"
VM4_NAME="${VM4_NAME:-ceph-node4}"
VM4_IP="${VM4_IP:-192.168.1.13}"

echo "Generating inventory for:"
echo "  Proxmox Host: $PROXMOX_API_HOST"
echo "  Number of VMs: $NUM_VMS"
echo ""

# Generate Proxmox inventory
cat > "$PROXMOX_INVENTORY" << EOF
# Proxmox Host Inventory
# Generated from environment variables on $(date)

[proxmox_host]
$PROXMOX_API_HOST ansible_user=$PROXMOX_SSH_USER

[proxmox_host:vars]
ansible_python_interpreter=/usr/bin/python3
# ansible_ssh_private_key_file=$PROXMOX_SSH_KEY
EOF

echo -e "${GREEN}✓${NC} Generated: $PROXMOX_INVENTORY"

# Generate VMs inventory
cat > "$VMS_INVENTORY" << EOF
# VM Inventory for Deployed Ceph Nodes
# Generated from environment variables on $(date)
# Update IP addresses after deployment if using DHCP

[ceph_nodes]
EOF

for i in $(seq 1 $NUM_VMS); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_IP=\$VM${i}_IP"
    echo "$VM_NAME ansible_host=$VM_IP" >> "$VMS_INVENTORY"
done

cat >> "$VMS_INVENTORY" << EOF

[ceph_nodes:vars]
ansible_user=$VM_SSH_USER
ansible_ssh_pass=$VM_ROOT_PASSWORD
# ansible_ssh_private_key_file=~/.ssh/id_rsa  # Uncomment after GitHub keys are imported
ansible_python_interpreter=/usr/bin/python3
ansible_host_key_checking=False
EOF

echo -e "${GREEN}✓${NC} Generated: $VMS_INVENTORY"
echo ""
echo "VMs in inventory:"
for i in $(seq 1 $NUM_VMS); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_IP=\$VM${i}_IP"
    echo "  - $VM_NAME @ $VM_IP"
done
echo ""
echo "Note: Update IP addresses in $VMS_INVENTORY if using DHCP"
