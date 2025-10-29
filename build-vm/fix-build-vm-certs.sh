#!/bin/bash
#
# Copyright (c) 2025 Darren Soothill
# Email: darren [at] soothill [dot] com
# License: MIT
set -e

# Fix CA certificates on existing build VM

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

BUILD_VM_ID="${BUILD_VM_ID:-100}"
PROXMOX_HOST="${PROXMOX_API_HOST:-proxmox}"
PROXMOX_USER="${PROXMOX_SSH_USER:-root}"

# Auto-detect build VM IP if not set
if [ -z "${BUILD_VM_IP}" ]; then
    echo "Auto-detecting build VM IP..."

    if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm status ${BUILD_VM_ID} >/dev/null 2>&1"; then
        # Try qm agent first (same as Proxmox GUI)
        BUILD_VM_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm agent ${BUILD_VM_ID} network-get-interfaces 2>/dev/null | grep -oP 'ip-address[\"\\s:]+\K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v '127.0.0.1' | head -1" || echo "")
    fi

    if [ -z "${BUILD_VM_IP}" ]; then
        echo "ERROR: Could not detect build VM IP"
        echo "Please set BUILD_VM_IP in .env or run: make detect-build-vm-ip"
        exit 1
    fi

    echo "✓ Detected build VM IP: ${BUILD_VM_IP}"
fi

echo "=========================================="
echo "Fixing CA Certificates on Build VM"
echo "=========================================="
echo "Build VM IP: ${BUILD_VM_IP}"
echo "=========================================="
echo ""

echo "Connecting to build VM and fixing CA certificates..."

ssh -o StrictHostKeyChecking=no root@${BUILD_VM_IP} bash <<'EOFVM'
set -e

echo "Installing/updating CA certificates..."
zypper --no-gpg-checks install -y ca-certificates ca-certificates-mozilla || true

echo "Updating CA certificate store..."
update-ca-certificates

echo "Refreshing repositories..."
zypper refresh

echo "✓ CA certificates fixed!"
echo ""
echo "Testing SSL connection..."
curl -I https://download.opensuse.org/distribution/leap/15.6/repo/oss/ 2>&1 | head -5
EOFVM

echo ""
echo "=========================================="
echo "Build VM CA Certificates Fixed!"
echo "=========================================="
echo ""
echo "You can now run: make build-image-remote"
echo ""
