#!/bin/bash
#
# Copyright (c) 2025 Darren Soothill
# Email: darren [at] soothill [dot] com
# License: MIT
set -e

# Remove the dedicated KIWI build VM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    set -a
    source "${SCRIPT_DIR}/../.env"
    set +a
fi

# Configuration
BUILD_VM_ID="${BUILD_VM_ID:-100}"
BUILD_VM_NAME="${BUILD_VM_NAME:-kiwi-builder}"
PROXMOX_HOST="${PROXMOX_API_HOST:-proxmox}"
PROXMOX_USER="${PROXMOX_SSH_USER:-root}"

echo "=========================================="
echo "Removing KIWI Build VM"
echo "=========================================="
echo "VM ID: ${BUILD_VM_ID}"
echo "VM Name: ${BUILD_VM_NAME}"
echo "Proxmox Host: ${PROXMOX_HOST}"
echo "=========================================="
echo ""

# Check if VM exists
if ! ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} >/dev/null 2>&1"; then
    echo "VM ${BUILD_VM_ID} does not exist. Nothing to remove."
    exit 0
fi

# Confirm deletion
read -p "Are you sure you want to remove VM ${BUILD_VM_ID} (${BUILD_VM_NAME})? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Stopping VM..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm stop ${BUILD_VM_ID}" || true

echo "Waiting for VM to stop..."
sleep 5

echo "Destroying VM..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm destroy ${BUILD_VM_ID}"

# Remove saved IP file
if [ -f "${SCRIPT_DIR}/build-vm-ip.txt" ]; then
    rm "${SCRIPT_DIR}/build-vm-ip.txt"
    echo "Removed saved IP configuration"
fi

echo ""
echo "=========================================="
echo "Build VM Removed Successfully"
echo "=========================================="
echo ""
echo "To create a new build VM:"
echo "  make deploy-build-vm"
echo "  or"
echo "  ./build-vm/deploy-build-vm.sh"
echo ""
