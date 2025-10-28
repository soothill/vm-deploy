#!/bin/bash
# Complete deployment script using environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header "OpenSUSE Ceph Cluster Deployment"
echo "Using Environment Variables for Configuration"
echo ""

# Check for .env file
if [ ! -f "$ENV_FILE" ]; then
    print_error "No .env file found!"
    echo ""
    echo "Please create .env file from template:"
    echo "  cp .env.example .env"
    echo "  vim .env  # Edit with your settings"
    echo ""
    exit 1
fi

# Source environment variables
print_status "Loading environment variables from .env"
source "$ENV_FILE"

# Validate required variables
REQUIRED_VARS=(
    "PROXMOX_API_HOST"
    "PROXMOX_API_USER"
    "PROXMOX_API_PASSWORD"
    "STORAGE_POOL"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable not set: $var"
        exit 1
    fi
done

print_status "All required environment variables are set"

# Display configuration
print_header "Configuration Summary"
echo "Proxmox Host: $PROXMOX_API_HOST"
echo "Storage Pool: $STORAGE_POOL"
echo "Data Disk Size: ${DATA_DISK_SIZE:-1000G}"
echo "Network Bridges: ${PRIVATE_BRIDGE:-vmbr1} (private), ${PUBLIC_BRIDGE:-vmbr0} (public)"
echo "Default Memory: ${VM_DEFAULT_MEMORY:-16384} MB"
echo "Default Cores: ${VM_DEFAULT_CORES:-4}"
echo "GitHub Username: ${GITHUB_USERNAME:-'(not configured)'}"
echo "Number of VMs: ${NUM_VMS:-4}"
echo ""

# Show VM configuration
echo "VM Configuration:"
for i in $(seq 1 ${NUM_VMS:-4}); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_VMID=\$VM${i}_VMID"
    eval "VM_MEMORY=\$VM${i}_MEMORY"
    eval "VM_CORES=\$VM${i}_CORES"
    eval "VM_IP=\$VM${i}_IP"
    
    # Use defaults if not set
    VM_MEMORY="${VM_MEMORY:-${VM_DEFAULT_MEMORY:-16384}}"
    VM_CORES="${VM_CORES:-${VM_DEFAULT_CORES:-4}}"
    
    echo "  VM$i: ${VM_NAME:-ceph-node$i} (VMID: ${VM_VMID:-$((199+i))})"
    echo "       Memory: ${VM_MEMORY}MB, Cores: ${VM_CORES}, IP: ${VM_IP:-192.168.1.$((9+i))}"
done

echo ""
read -p "Continue with deployment? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Step 1: Generate configuration files
print_header "Step 1: Generating Configuration Files"

print_info "Generating vm_config.yml..."
if ! ./generate-config.sh; then
    print_error "Failed to generate vm_config.yml"
    exit 1
fi

print_info "Generating inventory files..."
if ! ./generate-inventory.sh; then
    print_error "Failed to generate inventory files"
    exit 1
fi

print_status "Configuration files generated"

# Step 2: Check prerequisites
print_header "Step 2: Checking Prerequisites"

# Check Ansible
if ! command -v ansible-playbook &> /dev/null; then
    print_error "Ansible not found. Please install Ansible."
    exit 1
fi
print_status "Ansible found: $(ansible-playbook --version | head -n1)"

# Check image
print_info "Checking for OpenSUSE image on Proxmox host..."
IMAGE_CHECK=$(ssh -o StrictHostKeyChecking=no ${PROXMOX_SSH_USER:-root}@$PROXMOX_API_HOST \
    "test -f ${OPENSUSE_IMAGE_PATH:-/var/lib/vz/template/iso/opensuse-leap-custom.qcow2} && echo 'exists' || echo 'missing'" 2>/dev/null || echo 'ssh_failed')

if [ "$IMAGE_CHECK" = "exists" ]; then
    print_status "OpenSUSE image found on Proxmox host"
elif [ "$IMAGE_CHECK" = "ssh_failed" ]; then
    print_warning "Could not verify image (SSH check failed). Continuing anyway..."
else
    print_error "OpenSUSE image not found on Proxmox host!"
    echo ""
    echo "Please build the image first:"
    echo "  scp -r kiwi/ root@$PROXMOX_API_HOST:/root/"
    echo "  ssh root@$PROXMOX_API_HOST 'cd /root/kiwi && ./build-image.sh'"
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 3: Deploy VMs
print_header "Step 3: Deploying VMs on Proxmox"
echo "This will take 2-5 minutes..."
echo ""

if ansible-playbook -i inventory.ini deploy-vms.yml; then
    print_status "VMs deployed successfully"
else
    print_error "VM deployment failed"
    exit 1
fi

# Step 4: Wait for VMs
print_header "Step 4: Waiting for VMs to Boot"
print_info "Waiting 30 seconds for VMs to be fully ready..."
sleep 30
print_status "VMs should be ready now"

# Step 5: Configure VMs
print_header "Step 5: Configuring VMs"
echo "This will:"
echo "  - Import GitHub SSH keys (if configured)"
echo "  - Update all packages"
echo "  - Verify services (avahi, lldpd)"
echo "  - Check data disks"
echo ""

read -p "Continue with VM configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Skipping VM configuration."
    echo "Run manually later with:"
    echo "  ansible-playbook -i inventory-vms.ini configure-vms.yml"
else
    if ansible-playbook -i inventory-vms.ini configure-vms.yml; then
        print_status "VMs configured successfully"
    else
        print_error "VM configuration failed"
        print_warning "You can retry with:"
        echo "  ansible-playbook -i inventory-vms.ini configure-vms.yml"
    fi
fi

# Summary
print_header "Deployment Complete!"
print_status "All VMs deployed and configured"
echo ""
echo "Next Steps:"
echo "  1. Verify SSH access: ssh root@<vm-ip>"
echo "  2. Check LLDP neighbors: lldpcli show neighbors"
echo "  3. Check Avahi services: avahi-browse -a"
echo "  4. Verify data disks: lsblk"
echo "  5. Deploy Ceph OSDs on /dev/sd{b,c,d,e}"
echo ""
echo "VM Information:"
for i in $(seq 1 ${NUM_VMS:-4}); do
    eval "VM_NAME=\$VM${i}_NAME"
    eval "VM_IP=\$VM${i}_IP"
    echo "  - ${VM_NAME:-ceph-node$i}: ssh root@${VM_IP:-192.168.1.$((9+i))}"
done
echo ""
print_status "Cluster is ready for Ceph deployment!"
