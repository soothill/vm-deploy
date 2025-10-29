#!/bin/bash
#
# Copyright (c) 2025 Darren Soothill
# Email: darren [at] soothill [dot] com
# License: MIT
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

# Check if VM or Container ID already exists
echo "Checking if ID ${BUILD_VM_ID} is available..."

# Check for VM
IS_VM=""
IS_CT=""
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} >/dev/null 2>&1"; then
    IS_VM="yes"
fi

# Check for Container (LXC)
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct status ${BUILD_VM_ID} >/dev/null 2>&1"; then
    IS_CT="yes"
fi

if [ -n "${IS_VM}" ] || [ -n "${IS_CT}" ]; then
    echo ""
    echo "=========================================="
    if [ -n "${IS_VM}" ]; then
        echo "ERROR: VM ${BUILD_VM_ID} Already Exists!"
        RESOURCE_TYPE="VM"
        STATUS_CMD="qm status ${BUILD_VM_ID}"
        CONFIG_CMD="qm config ${BUILD_VM_ID}"
        STOP_CMD="qm stop ${BUILD_VM_ID}"
        DESTROY_CMD="qm destroy ${BUILD_VM_ID}"
    else
        echo "ERROR: Container (CT) ${BUILD_VM_ID} Already Exists!"
        RESOURCE_TYPE="Container"
        STATUS_CMD="pct status ${BUILD_VM_ID}"
        CONFIG_CMD="pct config ${BUILD_VM_ID}"
        STOP_CMD="pct stop ${BUILD_VM_ID}"
        DESTROY_CMD="pct destroy ${BUILD_VM_ID}"
    fi
    echo "=========================================="

    # Get resource details
    RESOURCE_STATUS=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "${STATUS_CMD} | awk '{print \$2}'")
    RESOURCE_NAME=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "${CONFIG_CMD} | grep '^name:' | awk '{print \$2}' || echo 'N/A'")
    RESOURCE_NAME=${RESOURCE_NAME:-"(unnamed)"}

    echo "${RESOURCE_TYPE} Details:"
    echo "  ID: ${BUILD_VM_ID}"
    echo "  Type: ${RESOURCE_TYPE}"
    echo "  Name: ${RESOURCE_NAME}"
    echo "  Status: ${RESOURCE_STATUS}"
    echo ""
    echo "Options:"
    echo "  1. Destroy and recreate (converts to VM)"
    echo "  2. Use a different BUILD_VM_ID"
    echo ""
    echo "=========================================="
    echo ""

    read -p "Do you want to destroy ${RESOURCE_TYPE} ${BUILD_VM_ID} and create a VM? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo ""
        echo "Stopping and removing existing ${RESOURCE_TYPE} ${BUILD_VM_ID} (${RESOURCE_NAME})..."
        ssh ${PROXMOX_USER}@${PROXMOX_HOST} "${STOP_CMD} || true"
        echo "Waiting for ${RESOURCE_TYPE} to stop..."
        sleep 5
        ssh ${PROXMOX_USER}@${PROXMOX_HOST} "${DESTROY_CMD}"
        echo "${RESOURCE_TYPE} ${BUILD_VM_ID} destroyed."
        echo ""
    else
        echo ""
        echo "=========================================="
        echo "Deployment Aborted"
        echo "=========================================="
        echo ""
        echo "To use a different VM ID, edit your .env file:"
        echo "  export BUILD_VM_ID=\"101\"  # Or any available ID"
        echo ""
        echo "To check available IDs:"
        echo "  ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm list'        # VMs"
        echo "  ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'pct list'       # Containers"
        echo "  ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'pvesh get /cluster/resources --type vm'"
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
echo "Step 4: Waiting for VM to boot and QEMU guest agent to start..."
echo "This may take 2-3 minutes for cloud-init to complete..."

if [ -n "${BUILD_VM_IP}" ]; then
    # Static IP configured, just wait for boot
    echo "Static IP configured: ${BUILD_VM_IP}"
    echo "Waiting 90 seconds for cloud-init to complete..."
    sleep 90
    VM_IP="${BUILD_VM_IP}"
else
    # DHCP - need to detect IP via guest agent
    echo "Waiting for QEMU guest agent to become available..."

    VM_IP=""

    # Get VM MAC address for fallback detection
    VM_MAC=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm config ${BUILD_VM_ID} | grep -o 'net0:.*' | grep -o '[0-9A-Fa-f:]\{17\}' | head -1")

    for i in {1..24}; do
        echo "Attempt $i/24: Detecting IP address..."

        # Method 1: Try QEMU guest agent first
        # Get the full output for debugging on first attempt
        if [ $i -eq 1 ]; then
            GUEST_OUTPUT=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm guest cmd ${BUILD_VM_ID} network-get-interfaces 2>&1" || echo "command failed")
            if echo "${GUEST_OUTPUT}" | grep -q "QEMU guest agent is not connected"; then
                echo "  Note: Guest agent is not connected yet"
            elif echo "${GUEST_OUTPUT}" | grep -q "command failed"; then
                echo "  Note: Guest agent command failed"
            elif echo "${GUEST_OUTPUT}" | grep -q "error"; then
                echo "  Note: Guest agent returned error"
            fi
        fi

        # Extract IPv4 address only (ignore IPv6 and localhost)
        # Use || echo "" to prevent set -e from exiting on failure
        # BSD-compatible grep (no -P flag)
        VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm guest cmd ${BUILD_VM_ID} network-get-interfaces 2>/dev/null | grep -o '\"ip-address\":\"[0-9][0-9.]*\"' | grep -o '[0-9][0-9.]*' | grep -v '127.0.0.1' | grep -v ':' | head -1" 2>/dev/null || echo "")

        if [ -n "${VM_IP}" ] && [ "${VM_IP}" != "." ] && [ "${VM_IP}" != ".." ]; then
            echo "✓ Successfully detected IP via guest agent: ${VM_IP}"
            break
        fi

        # Method 2: Try to find IP from ARP table using MAC address
        if [ -n "${VM_MAC}" ]; then
            VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "ip neigh show | grep -i '${VM_MAC}' | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1" || echo "")

            if [ -n "${VM_IP}" ]; then
                echo "✓ Successfully detected IP via ARP table: ${VM_IP}"
                echo "  (Guest agent not available, using network detection)"
                break
            fi
        fi

        # Method 3: Try DHCP leases file
        VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "grep -i '${VM_MAC}' /var/lib/misc/dnsmasq.leases 2>/dev/null | awk '{print \$3}' | head -1" || echo "")

        if [ -n "${VM_IP}" ]; then
            echo "✓ Successfully detected IP via DHCP leases: ${VM_IP}"
            echo "  (Guest agent not available, using DHCP records)"
            break
        fi

        # Method 4: Try qm agent command (used by Proxmox GUI)
        VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm agent ${BUILD_VM_ID} network-get-interfaces 2>/dev/null | grep -oP 'ip-address[\"\\s:]+\K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v '127.0.0.1' | head -1" || echo "")

        if [ -n "${VM_IP}" ]; then
            echo "✓ Successfully detected IP via qm agent: ${VM_IP}"
            echo "  (Using Proxmox agent interface)"
            break
        fi

        if [ $i -lt 24 ]; then
            if [ $i -eq 1 ]; then
                echo "  Waiting for VM to acquire IP address (guest agent: not responding, trying network detection)..."
            else
                echo "  Still waiting... (${i}0 seconds elapsed)"
            fi
            sleep 10
        fi
    done

    if [ -z "${VM_IP}" ]; then
        echo ""
        echo "=========================================="
        echo "WARNING: Could Not Detect IP Address"
        echo "=========================================="
        echo ""
        echo "Failed to detect IP address after 4 minutes using:"
        echo "  - QEMU guest agent (qm guest cmd)"
        echo "  - ARP table lookup (MAC: ${VM_MAC:-unknown})"
        echo "  - DHCP leases file"
        echo "  - Proxmox agent interface (qm agent)"
        echo ""
        echo "This could mean:"
        echo "  1. VM is still booting (cloud-init can be very slow)"
        echo "  2. Network connectivity issue"
        echo "  3. Bridge/VLAN configuration problem"
        echo ""
        echo "Options to resolve:"
        echo ""
        echo "1. Check VM console and get IP manually:"
        echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm terminal ${BUILD_VM_ID}'"
        echo "   # In console, run: ip a"
        echo "   # Press Ctrl+O to exit console"
        echo "   # Then set in .env: export BUILD_VM_IP=\"<ip-address>\""
        echo ""
        echo "2. Wait longer and try detection again:"
        echo "   make detect-build-vm-ip"
        echo ""
        echo "3. Check VM and network status:"
        echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm status ${BUILD_VM_ID}'"
        echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'pvesh get /nodes/${PROXMOX_NODE}/qemu/${BUILD_VM_ID}/status/current'"
        echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'ip neigh show | grep -i ${VM_MAC}'"
        echo ""
        echo "4. Check if VM got DHCP IP from router/DHCP server logs"
        echo ""
        echo "=========================================="
        exit 1
    fi
fi

echo ""
echo "Step 5: VM IP detected: ${VM_IP}"

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

echo "Waiting for cloud-init to complete..."
# Wait for cloud-init to finish (it may be running package updates)
cloud-init status --wait 2>/dev/null || echo "cloud-init not available or already finished"

echo "Waiting for zypper to become available..."
# Wait for zypper lock to be released (cloud-init or other processes may be using it)
for i in {1..30}; do
    if zypper refresh >/dev/null 2>&1; then
        echo "✓ Zypper is available"
        break
    fi
    if [ \$i -eq 1 ]; then
        echo "  Zypper is locked (likely by cloud-init), waiting..."
    else
        echo "  Attempt \$i/30: Still waiting for zypper lock to release..."
    fi
    sleep 10
done

echo "Installing CA certificates..."
# Install CA certificates first to avoid SSL issues
# Use --no-gpg-checks since we can't verify signatures without CA certs yet
zypper --no-gpg-checks install -y ca-certificates ca-certificates-mozilla

echo "Updating CA certificate store..."
update-ca-certificates

echo "Updating system..."
zypper refresh
zypper update -y

echo "Installing KIWI and required tools..."
zypper install -y \
    python3-kiwi \
    qemu-tools \
    kpartx \
    parted \
    git \
    rsync \
    openssh \
    htop \
    sysstat

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
