#!/bin/bash
set -e

# Build KIWI image on dedicated build VM and transfer to Proxmox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    set -a
    source "${SCRIPT_DIR}/../.env"
    set +a
fi

# Try to load build VM IP from saved file
if [ -f "${SCRIPT_DIR}/build-vm-ip.txt" ]; then
    source "${SCRIPT_DIR}/build-vm-ip.txt"
fi

# Configuration
BUILD_VM_IP="${BUILD_VM_IP:-}"
BUILD_VM_ID="${BUILD_VM_ID:-100}"
PROXMOX_HOST="${PROXMOX_API_HOST:-proxmox}"
PROXMOX_USER="${PROXMOX_SSH_USER:-root}"

# Auto-detect build VM IP if not set
if [ -z "${BUILD_VM_IP}" ]; then
    echo "BUILD_VM_IP not set, attempting to auto-detect from VM ${BUILD_VM_ID}..."

    # Check if build VM exists
    if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} >/dev/null 2>&1"; then
        VM_STATUS=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} | awk '{print \$2}'")

        if [ "${VM_STATUS}" != "running" ]; then
            echo "Build VM ${BUILD_VM_ID} is not running (status: ${VM_STATUS})"
            echo "Starting build VM..."
            ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm start ${BUILD_VM_ID}"
            echo "Waiting 60 seconds for VM to boot..."
            sleep 60
        fi

        # Get VM MAC address for fallback detection
        VM_MAC=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm config ${BUILD_VM_ID} | grep -o 'net0:.*' | grep -o '[0-9A-Fa-f:]\{17\}' | head -1")

        echo "Detecting IP address using multiple methods..."

        # Method 1: Try QEMU guest agent (qm guest cmd)
        BUILD_VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm guest cmd ${BUILD_VM_ID} network-get-interfaces 2>/dev/null | grep -oP '\"ip-address\":\"\K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v '127.0.0.1' | head -1" 2>/dev/null || echo "")

        if [ -z "${BUILD_VM_IP}" ]; then
            # Method 2: Try qm agent (used by Proxmox GUI)
            BUILD_VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm agent ${BUILD_VM_ID} network-get-interfaces 2>/dev/null | grep -oP 'ip-address[\"\\s:]+\K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v '127.0.0.1' | head -1" || echo "")
        fi

        if [ -z "${BUILD_VM_IP}" ] && [ -n "${VM_MAC}" ]; then
            # Method 3: Try ARP table
            BUILD_VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "ip neigh show | grep -i '${VM_MAC}' | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1" || echo "")
        fi

        if [ -z "${BUILD_VM_IP}" ] && [ -n "${VM_MAC}" ]; then
            # Method 4: Try DHCP leases
            BUILD_VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "grep -i '${VM_MAC}' /var/lib/misc/dnsmasq.leases 2>/dev/null | awk '{print \$3}' | head -1" || echo "")
        fi

        if [ -n "${BUILD_VM_IP}" ]; then
            echo "✓ Detected build VM IP: ${BUILD_VM_IP}"
            # Save for future use
            echo "BUILD_VM_IP=${BUILD_VM_IP}" > "${SCRIPT_DIR}/build-vm-ip.txt"
        fi
    fi
fi

# Image configuration
if [ -n "${IMAGE_PATH}" ]; then
    OUTPUT_DIR="$(dirname "${IMAGE_PATH}")"
    IMAGE_NAME="$(basename "${IMAGE_PATH}" .qcow2)"
else
    IMAGE_NAME="${OPENSUSE_IMAGE_NAME:-opensuse-leap-custom}"
    OUTPUT_DIR="$(dirname "${OPENSUSE_IMAGE_PATH:-/var/lib/vz/template/iso/opensuse-leap-custom.qcow2}")"
fi

# Strip .qcow2 extension if present (to avoid doubling it)
IMAGE_NAME="${IMAGE_NAME%.qcow2}"

FINAL_IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"

# Validate that OPENSUSE_IMAGE_PATH looks correct (not just a directory)
if [ -n "${OPENSUSE_IMAGE_PATH}" ] && [[ "${OPENSUSE_IMAGE_PATH}" == */ ]]; then
    echo "=========================================="
    echo "ERROR: Invalid OPENSUSE_IMAGE_PATH"
    echo "=========================================="
    echo ""
    echo "OPENSUSE_IMAGE_PATH is set to a directory:"
    echo "  ${OPENSUSE_IMAGE_PATH}"
    echo ""
    echo "It must be the FULL PATH including the .qcow2 filename, not just a directory."
    echo ""
    echo "Examples of CORRECT paths:"
    echo "  /var/lib/vz/template/iso/opensuse-leap-custom.qcow2"
    echo "  /wdred/iso/template/opensuse-leap-custom.qcow2"
    echo "  /mnt/storage/images/my-image.qcow2"
    echo ""
    echo "Examples of WRONG paths (ending with /):"
    echo "  /var/lib/vz/template/iso/"
    echo "  /wdred/iso/template/"
    echo ""
    echo "Please update your .env file with the correct full path."
    echo "=========================================="
    exit 1
fi

echo "=========================================="
echo "Building OpenSUSE Image on Build VM"
echo "=========================================="
echo "Configuration:"
echo "  Build VM IP: ${BUILD_VM_IP}"
echo "  Proxmox Host: ${PROXMOX_HOST}"
echo "  Image Name: ${IMAGE_NAME}"
echo "  Final Path: ${FINAL_IMAGE_PATH}"
echo "=========================================="
echo ""

# Validate configuration
if [ -z "${BUILD_VM_IP}" ]; then
    echo "=========================================="
    echo "ERROR: Could Not Determine Build VM IP"
    echo "=========================================="
    echo ""
    echo "The build VM IP address could not be auto-detected."
    echo ""
    echo "Options to resolve:"
    echo ""
    echo "1. Deploy a new build VM:"
    echo "   make deploy-build-vm"
    echo ""
    echo "2. Manually set BUILD_VM_IP if you know it:"
    echo "   # Add to .env:"
    echo "   export BUILD_VM_IP=\"192.168.1.x\""
    echo ""
    echo "3. Check if build VM (ID: ${BUILD_VM_ID}) exists and is running:"
    echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm list | grep ${BUILD_VM_ID}'"
    echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm status ${BUILD_VM_ID}'"
    echo ""
    echo "4. Get IP from Proxmox console:"
    echo "   ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm terminal ${BUILD_VM_ID}'"
    echo "   # In console, run: ip a"
    echo ""
    echo "=========================================="
    exit 1
fi

# Check connectivity to build VM
echo "Step 1: Checking connectivity to build VM..."
if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@${BUILD_VM_IP} "echo 'Connected'" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to build VM at ${BUILD_VM_IP}"
    echo ""
    echo "Please check:"
    echo "  1. Build VM is running: ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'qm status \${BUILD_VM_ID}'"
    echo "  2. IP address is correct"
    echo "  3. SSH keys are configured"
    echo ""
    exit 1
fi
echo "✓ Connected to build VM"

echo ""
echo "Step 2: Uploading KIWI configuration to build VM..."
rsync -avz --delete \
    "${SCRIPT_DIR}/../kiwi/" \
    root@${BUILD_VM_IP}:/root/kiwi-builds/

echo "✓ KIWI configuration uploaded"

echo ""
echo "Step 3: Building image on build VM..."
echo "This may take 15-40 minutes depending on network speed..."
echo ""

ssh root@${BUILD_VM_IP} bash <<EOFVM
set -e
cd /root/kiwi-builds

# Set build variables
export IMAGE_NAME="${IMAGE_NAME}"
export OUTPUT_DIR="/root/kiwi-builds/output"
export VM_ROOT_PASSWORD="${VM_ROOT_PASSWORD:-opensuse}"

echo "=========================================="
echo "Building OpenSUSE Image with KIWI"
echo "=========================================="
echo "Image: \${IMAGE_NAME}.qcow2"
echo "Output: \${OUTPUT_DIR}"
echo "Root Password: [configured from VM_ROOT_PASSWORD]"
echo "=========================================="
echo ""

# Create output directory
mkdir -p "\${OUTPUT_DIR}"

# Make scripts executable
chmod +x build-image.sh config.sh

# Run build
./build-image.sh

echo ""
echo "=========================================="
echo "Build Complete on Build VM"
echo "=========================================="
ls -lh "\${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"
echo ""
EOFVM

echo ""
echo "Step 4: Transferring image from build VM to Proxmox..."

# Create output directory on Proxmox
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "mkdir -p ${OUTPUT_DIR}"

# Transfer image from build VM to Proxmox via local machine
# This uses ssh port forwarding to avoid direct build VM -> Proxmox transfer
echo "Downloading from build VM..."
scp -o StrictHostKeyChecking=no \
    root@${BUILD_VM_IP}:/root/kiwi-builds/output/${IMAGE_NAME}.qcow2 \
    /tmp/${IMAGE_NAME}.qcow2

echo "Uploading to Proxmox..."
scp /tmp/${IMAGE_NAME}.qcow2 \
    ${PROXMOX_USER}@${PROXMOX_HOST}:${FINAL_IMAGE_PATH}

# Clean up local temp file
rm -f /tmp/${IMAGE_NAME}.qcow2

echo "✓ Image transferred successfully"

echo ""
echo "Step 5: Verifying image on Proxmox..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} bash <<EOFPROXMOX
echo "Image details:"
ls -lh ${FINAL_IMAGE_PATH}
echo ""
echo "Image info:"
qemu-img info ${FINAL_IMAGE_PATH}
EOFPROXMOX

echo ""
echo "Step 6: Cleaning up build VM..."
ssh root@${BUILD_VM_IP} bash <<EOFVM
# Clean up build directory to save space
rm -rf /root/kiwi-builds/build
rm -rf /root/kiwi-builds/output
echo "✓ Build artifacts cleaned"
EOFVM

echo ""
echo "=========================================="
echo "Image Build and Transfer Complete!"
echo "=========================================="
echo ""
echo "Image Details:"
echo "  Location: ${FINAL_IMAGE_PATH}"
echo "  Name: ${IMAGE_NAME}.qcow2"
echo ""
echo "Next Steps:"
echo "  1. Verify image: make check-image"
echo "  2. Deploy VMs: make deploy"
echo ""
echo "Build VM Status:"
echo "  The build VM is still running and can be reused"
echo "  To rebuild: make build-image-remote"
echo "  To remove: make remove-build-vm"
echo ""
echo "=========================================="
