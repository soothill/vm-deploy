#!/bin/bash
# Add required permissions to Proxmox API token

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# Load environment
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "ERROR: .env file not found at $ENV_FILE"
    echo "Please create it from .env.example"
    exit 1
fi

# Check if using API token
if [[ ! "$PROXMOX_API_USER" == *"!"* ]]; then
    echo "========================================"
    echo "Not Using API Token Authentication"
    echo "========================================"
    echo ""
    echo "Current user: $PROXMOX_API_USER"
    echo ""
    echo "This script is only needed when using API token authentication."
    echo "You are currently using password authentication, which doesn't"
    echo "require separate permission configuration."
    echo ""
    echo "No action needed."
    echo "========================================"
    exit 0
fi

TOKEN_ID=$(echo $PROXMOX_API_USER | cut -d'!' -f2)

echo "========================================"
echo "Adding Permissions to API Token"
echo "========================================"
echo ""
echo "Token ID: $TOKEN_ID"
echo "User: root@pam"
echo "Host: $PROXMOX_API_HOST"
echo ""
echo "This script will:"
echo "  1. Check current token configuration"
echo "  2. Add PVEVMAdmin role to the token on path /"
echo ""
echo "Required permissions for VM deployment:"
echo "  - VM.Monitor (query guest agent)"
echo "  - VM.Audit (check VM status)"
echo "  - VM.Allocate (create/delete VMs)"
echo "  - VM.Config.* (configure VMs)"
echo "  - Datastore.AllocateSpace (create disks)"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Connecting to Proxmox..."

ssh root@$PROXMOX_API_HOST bash << EOFREMOTE
TOKEN_ID="$TOKEN_ID"

echo "========================================"
echo "Step 1: Check token configuration"
echo "========================================"
pveum user token info root@pam \$TOKEN_ID

echo ""
echo "========================================"
echo "Step 2: Check current ACLs"
echo "========================================"
pveum acl list | grep -i "\$TOKEN_ID" || echo "No ACLs currently set for this token"

echo ""
echo "========================================"
echo "Step 3: Adding PVEVMAdmin role"
echo "========================================"
pveum acl modify / -token "root@pam!\$TOKEN_ID" -role PVEVMAdmin

echo ""
echo "========================================"
echo "Step 4: Verify new permissions"
echo "========================================"
pveum acl list | grep -i "\$TOKEN_ID"

echo ""
echo "✓ Permissions added successfully!"
echo ""
echo "The token now has PVEVMAdmin permissions which includes:"
echo "  ✓ VM.Monitor (query guest agent)"
echo "  ✓ VM.Audit (check VM status)"
echo "  ✓ VM.Allocate (create VMs)"
echo "  ✓ VM.Config.* (configure VMs)"
echo "  ✓ Datastore.AllocateSpace (disk operations)"
EOFREMOTE

echo ""
echo "========================================"
echo "Done! Test the configuration:"
echo "========================================"
echo ""
echo "1. Check IP detection:"
echo "   python3 scripts/proxmox_get_vm_ip.py \\"
echo "     \"\$PROXMOX_API_HOST\" \"\$PROXMOX_API_USER\" \"\$PROXMOX_API_PASSWORD\" \\"
echo "     \"\$PROXMOX_NODE\" 310 --debug"
echo ""
echo "2. Generate inventory:"
echo "   ./generate-inventory.sh"
echo ""
echo "3. Deploy VMs:"
echo "   make deploy"
echo ""
echo "========================================"
