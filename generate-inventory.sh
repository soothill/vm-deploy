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

# Auto-detect SSH key if not set
if [ -z "$PROXMOX_SSH_KEY" ]; then
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        DEFAULT_SSH_KEY="~/.ssh/id_ed25519"
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
        DEFAULT_SSH_KEY="~/.ssh/id_rsa"
    else
        DEFAULT_SSH_KEY="~/.ssh/id_rsa"
    fi
else
    DEFAULT_SSH_KEY="$PROXMOX_SSH_KEY"
fi

# Set defaults
PROXMOX_API_HOST="${PROXMOX_API_HOST:-proxmox.example.com}"
PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-root}"
PROXMOX_SSH_KEY="${DEFAULT_SSH_KEY}"
VM_SSH_USER="${VM_SSH_USER:-root}"
VM_ROOT_PASSWORD="${VM_ROOT_PASSWORD:-opensuse}"
NUM_VMS="${NUM_VMS:-4}"

# VM defaults (must match generate-config.sh)
VM1_NAME="${VM1_NAME:-ceph-node1}"
VM1_VMID="${VM1_VMID:-200}"
VM1_IP="${VM1_IP:-192.168.1.10}"
VM2_NAME="${VM2_NAME:-ceph-node2}"
VM2_VMID="${VM2_VMID:-201}"
VM2_IP="${VM2_IP:-192.168.1.11}"
VM3_NAME="${VM3_NAME:-ceph-node3}"
VM3_VMID="${VM3_VMID:-202}"
VM3_IP="${VM3_IP:-192.168.1.12}"
VM4_NAME="${VM4_NAME:-ceph-node4}"
VM4_VMID="${VM4_VMID:-203}"
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
ansible_ssh_private_key_file=$PROXMOX_SSH_KEY
EOF

echo -e "${GREEN}✓${NC} Generated: $PROXMOX_INVENTORY"

# Generate VMs inventory
cat > "$VMS_INVENTORY" << EOF
# VM Inventory for Deployed Ceph Nodes
# Generated from environment variables on $(date)
# IP addresses detected from Proxmox via qemu-guest-agent

[ceph_nodes]
EOF

echo "Detecting VM IP addresses from Proxmox..."
echo ""

# Function to get VM IP from Proxmox
get_vm_ip() {
    local vm_name=$1
    local vmid=$2
    local detected_ip=""

    # Try to get IP from qemu-guest-agent
    # The output is JSON with ip-address fields, we want IPv4 addresses only (not 127.0.0.1 or IPv6)
    # Use awk with simple regex matching for compatibility with older awk versions
    detected_ip=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_SSH_USER@$PROXMOX_API_HOST" \
        'qm guest cmd '"$vmid"' network-get-interfaces 2>/dev/null | \
         awk '"'"'
         /"ip-address"/ && /"ip-address":"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"/ {
             line = $0
             sub(/.*"ip-address":"/, "", line)
             sub(/".*/, "", line)
             if (line !~ /^127\./ && line ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                 print line
                 exit
             }
         }'"'"' 2>/dev/null || echo "")

    # If guest agent doesn't work, try MAC address lookup in ARP table
    if [ -z "$detected_ip" ]; then
        local mac=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_SSH_USER@$PROXMOX_API_HOST" \
            "qm config $vmid 2>/dev/null | \
             grep 'net[0-9]:' | \
             sed -n 's/.*=\([0-9A-Fa-f:]*\).*/\1/p' | \
             head -1" 2>/dev/null || echo "")

        if [ -n "$mac" ]; then
            detected_ip=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_SSH_USER@$PROXMOX_API_HOST" \
                "ip neigh show | grep -i '$mac' | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\) .*/\1/p' | head -1" 2>/dev/null || echo "")
        fi
    fi

    echo "$detected_ip"
}

# Build inventory with detected IPs
for i in $(seq 1 $NUM_VMS); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_VMID=\$VM${i}_VMID"
    eval "FALLBACK_IP=\$VM${i}_IP"

    # Try to detect IP from Proxmox
    echo -n "  ${VM_NAME} (VMID: ${VM_VMID}): "
    DETECTED_IP=$(get_vm_ip "$VM_NAME" "$VM_VMID")

    # Use detected IP or fall back to configured IP
    if [ -n "$DETECTED_IP" ] && [ "$DETECTED_IP" != "." ]; then
        VM_IP="$DETECTED_IP"
        echo "${DETECTED_IP} (detected via guest-agent)"
    else
        VM_IP="$FALLBACK_IP"
        echo "${FALLBACK_IP} (fallback - unable to detect)"
    fi

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

echo ""
echo -e "${GREEN}✓${NC} Generated: $VMS_INVENTORY"
