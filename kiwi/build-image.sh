#!/bin/bash
set -e

# Build script for OpenSUSE Leap minimal image using KIWI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

# Allow customization via environment variables
# IMAGE_PATH takes precedence, otherwise derive from IMAGE_NAME
if [ -n "${IMAGE_PATH}" ]; then
    # Extract directory and filename from IMAGE_PATH
    OUTPUT_DIR="$(dirname "${IMAGE_PATH}")"
    IMAGE_NAME="$(basename "${IMAGE_PATH}" .qcow2)"
else
    # Use defaults or environment variables
    IMAGE_NAME="${IMAGE_NAME:-opensuse-leap-custom}"
    OUTPUT_DIR="${OUTPUT_DIR:-/var/lib/vz/template/iso}"
fi

echo "========================================"
echo "Building OpenSUSE Leap Minimal Image"
echo "========================================"
echo "Configuration:"
echo "  Output directory: ${OUTPUT_DIR}"
echo "  Image name: ${IMAGE_NAME}"
echo "  Full path: ${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"
echo "========================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

# Detect OS and set package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
else
    echo "ERROR: Cannot detect OS type"
    exit 1
fi

echo "Detected OS: ${OS_ID}"

# Check if kiwi-ng is installed
if ! command -v kiwi-ng &> /dev/null; then
    echo "KIWI not found. Installing..."

    case "${OS_ID}" in
        debian|ubuntu)
            # Proxmox is Debian-based
            echo "Installing python3-kiwi on Debian/Ubuntu/Proxmox..."
            apt-get update
            apt-get install -y python3-kiwi
            ;;
        opensuse*|sles)
            # OpenSUSE or SLES
            echo "Installing python3-kiwi on OpenSUSE/SLES..."
            zypper install -y python3-kiwi
            ;;
        rhel|centos|fedora|rocky|alma)
            # Red Hat based systems
            echo "Installing python3-kiwi on RHEL/CentOS/Fedora..."
            if command -v dnf &> /dev/null; then
                dnf install -y python3-kiwi
            else
                yum install -y python3-kiwi
            fi
            ;;
        *)
            echo "ERROR: Unsupported OS: ${OS_ID}"
            echo "Please install python3-kiwi manually:"
            echo "  - Debian/Ubuntu/Proxmox: apt-get install python3-kiwi"
            echo "  - OpenSUSE: zypper install python3-kiwi"
            echo "  - RHEL/CentOS: dnf install python3-kiwi"
            echo "  - Or via pip: pip3 install kiwi"
            exit 1
            ;;
    esac

    # Verify installation
    if ! command -v kiwi-ng &> /dev/null; then
        echo "ERROR: KIWI installation failed"
        echo "Trying pip installation as fallback..."
        if command -v pip3 &> /dev/null; then
            pip3 install kiwi
        else
            echo "ERROR: pip3 not found. Please install python3-kiwi manually."
            exit 1
        fi
    fi
fi

echo "KIWI version: $(kiwi-ng --version 2>&1 | head -n1)"

# Create build directory
echo "Creating build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Make config.sh executable
chmod +x "${SCRIPT_DIR}/config.sh"

# Build the image
echo "Building image with KIWI..."
echo "This may take 10-30 minutes depending on your internet connection..."

kiwi-ng --type oem \
    system build \
    --description "${SCRIPT_DIR}" \
    --target-dir "${BUILD_DIR}"

# Find the generated qcow2 image
GENERATED_IMAGE=$(find "${BUILD_DIR}" -name "*.qcow2" | head -n 1)

if [ -z "$GENERATED_IMAGE" ]; then
    echo "ERROR: No qcow2 image found in build directory"
    exit 1
fi

echo "========================================"
echo "Image built successfully!"
echo "Image location: ${GENERATED_IMAGE}"
echo "========================================"

# Copy to Proxmox template directory
echo "Copying image to Proxmox template directory..."
mkdir -p "${OUTPUT_DIR}"
cp "${GENERATED_IMAGE}" "${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"

echo "========================================"
echo "Build Complete!"
echo "========================================"
echo "Image saved to: ${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"
echo ""
echo "Image size:"
ls -lh "${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"
echo ""
echo "You can now run the Ansible playbook to deploy VMs:"
echo "  cd .."
echo "  ansible-playbook -i inventory.ini deploy-vms.yml"
echo "========================================"
