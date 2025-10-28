#!/bin/bash
set -e

# Deploy a dedicated OpenSUSE build VM for KIWI image creation
# This VM runs on Proxmox and is used solely for building images

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration from .env if it exists
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    set -a
    source "${SCRIPT_DIR}/../.env"
    set +a
fi

# Build VM configuration with defaults
BUILD_VM_ID="${BUILD_VM_ID:-100}"
BUILD_VM_NAME="${BUILD_VM_NAME:-kiwi-builder}"
BUILD_VM_MEMORY="${BUILD_VM_MEMORY:-4096}"
BUILD_VM_CORES="${BUILD_VM_CORES:-4}"
BUILD_VM_DISK_SIZE="${BUILD_VM_DISK_SIZE:-50G}"
BUILD_VM_STORAGE="${BUILD_VM_STORAGE:-local-lvm}"
BUILD_VM_BRIDGE="${BUILD_VM_BRIDGE:-vmbr0}"
BUILD_VM_IP="${BUILD_VM_IP:-}"  # Leave empty for DHCP

# Proxmox configuration
PROXMOX_HOST="${PROXMOX_API_HOST:-proxmox}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
PROXMOX_USER="${PROXMOX_SSH_USER:-root}"

# OpenSUSE cloud image URL
OPENSUSE_CLOUD_IMAGE_URL="https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2"

echo "=========================================="
echo "Deploying KIWI Build VM on Proxmox"
echo "=========================================="
echo "Configuration:"
echo "  Proxmox Host: ${PROXMOX_HOST}"
echo "  Proxmox Node: ${PROXMOX_NODE}"
echo "  VM ID: ${BUILD_VM_ID}"
echo "  VM Name: ${BUILD_VM_NAME}"
echo "  Memory: ${BUILD_VM_MEMORY} MB"
echo "  CPU Cores: ${BUILD_VM_CORES}"
echo "  Disk Size: ${BUILD_VM_DISK_SIZE}"
echo "  Storage: ${BUILD_VM_STORAGE}"
echo "  Network: ${BUILD_VM_BRIDGE}"
if [ -n "${BUILD_VM_IP}" ]; then
    echo "  IP Address: ${BUILD_VM_IP}"
else
    echo "  IP Address: DHCP"
fi
echo "=========================================="
echo ""

# Check if VM already exists
echo "Checking if VM ${BUILD_VM_ID} already exists..."
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} >/dev/null 2>&1"; then
    echo ""
    echo "=========================================="
    echo "ERROR: VM ${BUILD_VM_ID} Already Exists!"
    echo "=========================================="

    # Get VM details
    VM_STATUS=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} | awk '{print \$2}'")
    VM_NAME=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm config ${BUILD_VM_ID} | grep '^name:' | awk '{print \$2}'")

    echo "VM Details:"
    echo "  VM ID: ${BUILD_VM_ID}"
    echo "  VM Name: ${VM_NAME}"
    echo "  Status: ${VM_STATUS}"
    echo ""
    echo "Options:"
    echo "  1. Destroy and recreate this VM"
    echo "  2. Use a different VM ID"
    echo "  3. Keep existing VM (if it's already configured)"
    echo ""
    echo "=========================================="
    echo ""

    read -p "Do you want to destroy VM ${BUILD_VM_ID} and recreate it? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo ""
        echo "Stopping and removing existing VM ${BUILD_VM_ID} (${VM_NAME})..."
        ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm stop ${BUILD_VM_ID} || true"
        echo "Waiting for VM to stop..."
        sleep 5
        ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm destroy ${BUILD_VM_ID}"
        echo "VM ${BUILD_VM_ID} destroyed."
        echo ""
    else
        echo ""
        echo "=========================================="
        echo "Deployment Aborted"
        echo "=========================================="
        echo ""
        echo "To use a different VM ID, edit your .env file:"
        echo "  export BUILD_VM_ID=\"101\"  # Or any available VM ID"
        echo ""
        echo "To check available VM IDs:"
        echo "  ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm list'"
        echo ""
        echo "If VM ${BUILD_VM_ID} is already your build VM:"
        echo "  You can use it directly: make build-image-remote"
        echo "  Or check its status: make build-vm-status"
        echo ""
        echo "=========================================="
        exit 1
    fi
fi

echo ""
echo "Step 1: Downloading OpenSUSE cloud image..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} bash <<EOF
set -e
cd /tmp
if [ ! -f opensuse-leap-cloud.qcow2 ]; then
    echo "Downloading OpenSUSE Leap 15.6 cloud image..."
    # Force IPv4 to avoid IPv6 connection issues
    wget --inet4-only -O opensuse-leap-cloud.qcow2 "${OPENSUSE_CLOUD_IMAGE_URL}" || \
    wget -4 -O opensuse-leap-cloud.qcow2 "${OPENSUSE_CLOUD_IMAGE_URL}" || \
    curl -4 -L -o opensuse-leap-cloud.qcow2 "${OPENSUSE_CLOUD_IMAGE_URL}"
else
    echo "Cloud image already downloaded."
fi
EOF

echo ""
echo "Step 2: Creating VM ${BUILD_VM_ID}..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} bash <<EOF
set -e

# Create VM
qm create ${BUILD_VM_ID} \
    --name ${BUILD_VM_NAME} \
    --memory ${BUILD_VM_MEMORY} \
    --cores ${BUILD_VM_CORES} \
    --net0 virtio,bridge=${BUILD_VM_BRIDGE} \
    --serial0 socket \
    --vga serial0 \
    --agent enabled=1

echo "VM created."

# Import disk
echo "Importing cloud image disk..."
qm importdisk ${BUILD_VM_ID} /tmp/opensuse-leap-cloud.qcow2 ${BUILD_VM_STORAGE}

# Get the imported disk name
DISK=\$(pvesm list ${BUILD_VM_STORAGE} | grep "vm-${BUILD_VM_ID}-disk-0" | awk '{print \$1}')

# Attach disk
echo "Attaching disk..."
qm set ${BUILD_VM_ID} --scsi0 \${DISK}

# Resize disk if larger than base image
echo "Resizing disk to ${BUILD_VM_DISK_SIZE}..."
qm resize ${BUILD_VM_ID} scsi0 ${BUILD_VM_DISK_SIZE}

# Add cloud-init drive
echo "Adding cloud-init drive..."
qm set ${BUILD_VM_ID} --ide2 ${BUILD_VM_STORAGE}:cloudinit

# Set boot disk
qm set ${BUILD_VM_ID} --boot c --bootdisk scsi0

# Configure cloud-init
qm set ${BUILD_VM_ID} --ciuser root
qm set ${BUILD_VM_ID} --sshkeys /root/.ssh/authorized_keys

# Configure network
if [ -n "${BUILD_VM_IP}" ]; then
    echo "Configuring static IP..."
    qm set ${BUILD_VM_ID} --ipconfig0 ip=${BUILD_VM_IP}/24,gw=\$(echo ${BUILD_VM_IP} | cut -d. -f1-3).1
else
    echo "Configuring DHCP..."
    qm set ${BUILD_VM_ID} --ipconfig0 ip=dhcp
fi

echo "VM configuration complete."
EOF

echo ""
echo "Step 3: Starting VM..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm start ${BUILD_VM_ID}"

echo ""
echo "Step 4: Waiting for VM to boot (60 seconds)..."
sleep 60

echo ""
echo "Step 5: Getting VM IP address..."
if [ -n "${BUILD_VM_IP}" ]; then
    VM_IP="${BUILD_VM_IP}"
else
    VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm guest cmd ${BUILD_VM_ID} network-get-interfaces 2>/dev/null | grep -oP '(?<=\"ip-address\":\")[0-9.]+' | grep -v 127.0.0.1 | head -1" || echo "")

    if [ -z "${VM_IP}" ]; then
        echo "WARNING: Could not detect IP address automatically."
        echo "Please check VM console: ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm terminal ${BUILD_VM_ID}'"
        echo "Or manually set BUILD_VM_IP in .env"
        exit 1
    fi
fi

echo "VM IP: ${VM_IP}"

echo ""
echo "Step 6: Installing KIWI and dependencies on build VM..."
echo "Waiting for SSH to be available..."
for i in {1..30}; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${VM_IP} "echo 'SSH connected'" 2>/dev/null; then
        echo "SSH connection established."
        break
    fi
    echo "Attempt $i/30: Waiting for SSH..."
    sleep 10
done

ssh -o StrictHostKeyChecking=no root@${VM_IP} bash <<'EOFVM'
set -e

echo "Updating system..."
zypper refresh
zypper update -y

echo "Installing KIWI and required tools..."
zypper install -y \
    python3-kiwi \
    qemu-tools \
    git \
    rsync \
    openssh

echo "Creating build directory..."
mkdir -p /root/kiwi-builds

echo "KIWI installation complete!"
kiwi-ng --version
EOFVM

echo ""
echo "=========================================="
echo "Build VM Deployment Complete!"
echo "=========================================="
echo ""
echo "VM Details:"
echo "  VM ID: ${BUILD_VM_ID}"
echo "  VM Name: ${BUILD_VM_NAME}"
echo "  IP Address: ${VM_IP}"
echo "  SSH Access: ssh root@${VM_IP}"
echo ""
echo "KIWI Build Environment Ready!"
echo ""
echo "Next Steps:"
echo "  1. Update .env with BUILD_VM_IP=${VM_IP}"
echo "  2. Run: make build-image-remote"
echo "     This will build the image on the build VM and transfer to Proxmox"
echo ""
echo "Manual access:"
echo "  ssh root@${VM_IP}"
echo "  cd /root/kiwi-builds"
echo ""
echo "=========================================="

# Save VM IP to a file for later use
echo "BUILD_VM_IP=${VM_IP}" > "${SCRIPT_DIR}/build-vm-ip.txt"
echo ""
echo "VM IP saved to: ${SCRIPT_DIR}/build-vm-ip.txt"
