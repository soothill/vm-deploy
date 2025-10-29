#!/bin/bash
#
# Copyright (c) 2025 Darren Soothill
# Email: darren [at] soothill [dot] com
# License: MIT
# Check Proxmox API token permissions

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

echo "========================================"
echo "Checking API Token Permissions"
echo "========================================"
echo "Token: $PROXMOX_API_USER"
echo "Host: $PROXMOX_API_HOST"
echo ""

# Test authentication
echo "1. Testing authentication..."
curl -k -s \
  -H "Authorization: PVEAPIToken=$PROXMOX_API_USER=$PROXMOX_API_PASSWORD" \
  "https://$PROXMOX_API_HOST:8006/api2/json/access/permissions" \
  | python3 -m json.tool 2>/dev/null || echo "Authentication failed or no permissions found"

echo ""
echo "2. Checking ACL entries for this token..."
TOKEN_ID=$(echo $PROXMOX_API_USER | cut -d'!' -f2)
ssh root@$PROXMOX_API_HOST "pveum acl list" | grep -i "$TOKEN_ID" || echo "No ACL entries found for this token"

echo ""
echo "3. Checking all API tokens..."
ssh root@$PROXMOX_API_HOST "pveum user token list root@pam"

echo ""
echo "4. Checking token details..."
ssh root@$PROXMOX_API_HOST "pveum user token info root@pam $TOKEN_ID"

echo ""
echo "========================================"
echo "Analysis:"
echo ""
echo "If you see '403 Permission check failed' errors, run:"
echo "  ./scripts/fix-token-permissions.sh"
echo ""
echo "Or manually add permissions via Proxmox web UI:"
echo "  Datacenter → Permissions → Add → API Token Permission"
echo "  Path: /"
echo "  API Token: $PROXMOX_API_USER"
echo "  Role: PVEVMAdmin"
echo "========================================"
