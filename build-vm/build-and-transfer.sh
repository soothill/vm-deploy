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
PROXMOX_HOST="${PROXMOX_API_HOST:-proxmox}"
PROXMOX_USER="${PROXMOX_SSH_USER:-root}"

# Image configuration
if [ -n "${IMAGE_PATH}" ]; then
    OUTPUT_DIR="$(dirname "${IMAGE_PATH}")"
    IMAGE_NAME="$(basename "${IMAGE_PATH}" .qcow2)"
else
    IMAGE_NAME="${OPENSUSE_IMAGE_NAME:-opensuse-leap-custom}"
    OUTPUT_DIR="$(dirname "${OPENSUSE_IMAGE_PATH:-/var/lib/vz/template/iso/opensuse-leap-custom.qcow2}")"
fi

FINAL_IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"

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
    echo "ERROR: BUILD_VM_IP not set!"
    echo ""
    echo "Please set BUILD_VM_IP in .env or run:"
    echo "  ./build-vm/deploy-build-vm.sh"
    echo ""
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

echo "=========================================="
echo "Building OpenSUSE Image with KIWI"
echo "=========================================="
echo "Image: \${IMAGE_NAME}.qcow2"
echo "Output: \${OUTPUT_DIR}"
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
