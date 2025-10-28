#!/bin/bash
set -e

# Quick deployment script for OpenSUSE VMs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "OpenSUSE VM Quick Deployment"
echo "========================================"
echo ""

# Check if image exists
IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"

if [ ! -f "$IMAGE_PATH" ]; then
    echo "⚠️  OpenSUSE image not found at $IMAGE_PATH"
    echo ""
    echo "You need to build the image first:"
    echo "  1. Copy kiwi directory to your Proxmox host"
    echo "  2. Run: cd kiwi && ./build-image.sh"
    echo ""
    echo "Would you like instructions? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Building the image on Proxmox host:"
        echo "-----------------------------------"
        echo "scp -r kiwi/ root@proxmox:/root/"
        echo "ssh root@proxmox"
        echo "cd /root/kiwi"
        echo "chmod +x build-image.sh"
        echo "./build-image.sh"
        echo ""
    fi
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "⚠️  Ansible not found. Installing..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y ansible
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ansible
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y ansible
    else
        echo "❌ Could not install Ansible. Please install manually."
        exit 1
    fi
fi

# Check if configuration exists
if [ ! -f "${SCRIPT_DIR}/vars/vm_config.yml" ]; then
    echo "❌ Configuration file not found: vars/vm_config.yml"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/inventory.ini" ]; then
    echo "❌ Inventory file not found: inventory.ini"
    exit 1
fi

# Display configuration summary
echo "📋 Configuration Summary:"
echo "-----------------------------------"
echo "Configuration file: vars/vm_config.yml"
echo "Inventory file: inventory.ini"
echo ""

# Ask for confirmation
echo "This will deploy 4 OpenSUSE VMs to your Proxmox host."
echo ""
echo "Ready to deploy? (y/n)"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "🚀 Starting deployment..."
echo "========================================"

# Run Ansible playbook
cd "${SCRIPT_DIR}"
ansible-playbook -i inventory.ini deploy-vms.yml

echo ""
echo "========================================"
echo "✅ Deployment complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Access VMs via SSH"
echo "  2. Configure static IPs if needed"
echo "  3. Format and mount data disks"
echo ""
echo "See README.md for more information."
