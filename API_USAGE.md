# Proxmox API Usage Guide

This document explains how this project uses the Proxmox API and when SSH commands are still required.

## Overview: Hybrid Approach

This project uses a **hybrid approach** combining both Proxmox API and SSH+CLI commands:

- **Proxmox API**: Used for frequent operations (monitoring, IP detection, status checks)
- **SSH + qm commands**: Used for deployment operations (disk management, complex configurations)

This is the **recommended approach** in the Proxmox community because some operations have no direct API equivalent.

## Why Hybrid?

### Operations WITH Good API Support ✅

These operations use the Proxmox REST API:

| Operation | Implementation | Why API |
|-----------|----------------|---------|
| **VM IP Detection** | `scripts/proxmox_get_vm_ip.py` | Frequent operation, API is fast and reliable |
| **VM Status Checks** | `library/proxmox_api.py` | Read-only, perfect for API |
| **Guest Agent Queries** | `library/proxmox_api.py` | Native API support via qemu-guest-agent |
| **VM Start/Stop** | `library/proxmox_api.py` | Simple state changes |
| **VM Delete** | `library/proxmox_api.py` | Clean API support |
| **Inventory Generation** | `generate-inventory.sh` | Runs frequently, benefits from API |

### Operations WITHOUT API Support ⚠️

These operations use SSH + qm commands:

| Operation | Why SSH/CLI Required |
|-----------|----------------------|
| **`qm importdisk`** | **No API equivalent exists** - must use CLI |
| **Complex disk configuration** | `qm set --scsi0 pool:disk,discard=on,size=50G` - API requires multiple calls with complex syntax |
| **Storage type detection** | `pvesm status` - CLI output is simpler to parse |
| **Cloud-init with IDE devices** | `qm set --ide2 pool:cloudinit` - Limited API support |
| **Boot order configuration** | `qm set --boot order=scsi0` - Simpler via CLI |

### Technical Limitations

The Proxmox API doesn't support:

1. **Disk Import**: No `/api2/json/nodes/{node}/qemu/{vmid}/importdisk` endpoint
2. **Storage Probing**: No API to query storage capabilities before disk creation
3. **Atomic Multi-Parameter Updates**: `qm set` with 10+ parameters is one atomic operation; API requires multiple calls

These are **known limitations** acknowledged by Proxmox developers. See: [Proxmox Forum - API Limitations](https://forum.proxmox.com/threads/api-importdisk.95856/)

## Authentication

### API Token Authentication (Recommended)

API tokens provide secure, non-interactive authentication:

```bash
# .env configuration
export PROXMOX_API_USER="root@pam!tokenid"
export PROXMOX_API_PASSWORD="your-api-token-secret"
export PROXMOX_API_HOST="proxmox.local"
export PROXMOX_NODE="proxmox"
```

**Benefits:**
- No password exposure
- Granular permissions (can restrict to specific VMs/operations)
- Auditable (token usage is logged separately)
- Revocable without changing passwords

**Setup:**
1. Create token in Proxmox: `Datacenter → Permissions → API Tokens`
2. Grant permissions: `make fix-token` (adds PVEVMAdmin role)
3. Test: `make check-token`

### Password Authentication (Alternative)

Traditional username/password authentication:

```bash
# .env configuration
export PROXMOX_API_USER="root@pam"
export PROXMOX_API_PASSWORD="your-root-password"
```

**Trade-offs:**
- ✅ Simpler setup (no token creation)
- ✅ Inherits all user permissions
- ⚠️ Password in .env file (secure it properly)
- ⚠️ No audit trail separation

### SSH Key Authentication (Required for Deployment)

SSH access is still required for deployment operations:

```bash
# SSH configuration
export PROXMOX_SSH_USER="root"
# SSH key auto-detected (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)
```

**Required for:**
- VM deployment (`make deploy`)
- Image building (`make build-image-remote`)
- Disk operations (import, configuration)

**Setup:**
```bash
# Copy your SSH key to Proxmox
ssh-copy-id root@proxmox.local

# Test connection
ssh root@proxmox.local "hostname"
```

## Implementation Details

### Python API Client

The `library/proxmox_api.py` module provides:

```python
class ProxmoxAPI:
    def __init__(self, host, user, password, node):
        # Auto-detects token vs password authentication
        self.use_api_token = '!' in user

    def authenticate(self):
        # Token auth: Uses Authorization header (no session)
        # Password auth: Gets ticket + CSRF token

    def vm_exists(self, vmid): ...
    def get_vm_status(self, vmid): ...
    def start_vm(self, vmid): ...
    def stop_vm(self, vmid): ...
    def delete_vm(self, vmid): ...
    def get_guest_network_interfaces(self, vmid): ...
```

**Key Features:**
- Automatic authentication method detection
- No session management needed for API tokens
- SSL verification disabled (self-signed certificates)
- Comprehensive error handling

### IP Detection Script

The `scripts/proxmox_get_vm_ip.py` script:

```bash
# Automatically uses API token or password based on PROXMOX_API_USER
python3 scripts/proxmox_get_vm_ip.py \
  "$PROXMOX_API_HOST" \
  "$PROXMOX_API_USER" \
  "$PROXMOX_API_PASSWORD" \
  "$PROXMOX_NODE" \
  <vmid> \
  --debug
```

**How it works:**
1. Detects authentication method (checks for `!` in username)
2. Authenticates with Proxmox API
3. Queries VM guest agent via `/api2/json/nodes/{node}/qemu/{vmid}/agent/network-get-interfaces`
4. Parses interfaces and returns first non-loopback IPv4 address

### Inventory Generation

The `generate-inventory.sh` script uses the API for IP detection:

```bash
# For each VM, call the Python API script
detected_ip=$(python3 "$SCRIPT_DIR/scripts/proxmox_get_vm_ip.py" \
    "$PROXMOX_API_HOST" \
    "$PROXMOX_API_USER" \
    "$PROXMOX_API_PASSWORD" \
    "$PROXMOX_NODE" \
    "$vmid" 2>&1 || echo "")
```

**Benefits:**
- No SSH connection needed for inventory generation
- Faster than SSH (parallel API calls possible)
- Works with API tokens (no password required)

## Permission Requirements

### API Token Permissions

For full functionality, the API token needs:

| Permission | Required For | Added by `make fix-token` |
|------------|--------------|---------------------------|
| `VM.Monitor` | Guest agent queries, IP detection | ✅ |
| `VM.Audit` | Status checks, config reads | ✅ |
| `VM.Allocate` | Create/delete VMs | ✅ |
| `VM.Config.Disk` | Disk configuration | ✅ |
| `VM.Config.Network` | Network configuration | ✅ |
| `VM.PowerMgmt` | Start/stop VMs | ✅ |
| `Datastore.AllocateSpace` | Create disks | ✅ |

**Grant all at once:**
```bash
make fix-token
```

**Or manually via Proxmox web UI:**
1. `Datacenter → Permissions → Add → API Token Permission`
2. Path: `/`
3. API Token: `root@pam!tokenid`
4. Role: `PVEVMAdmin`
5. Propagate: ✅ (checked)

### SSH User Permissions

SSH access requires root or equivalent:

```bash
# Test SSH permissions
ssh root@proxmox.local "qm list"
ssh root@proxmox.local "pvesm status"
```

## Troubleshooting

### API Token Issues

**Problem: 403 Permission check failed**

```bash
# Check current permissions
make check-token

# Fix permissions
make fix-token

# Verify fix
python3 scripts/proxmox_get_vm_ip.py \
  "$PROXMOX_API_HOST" "$PROXMOX_API_USER" "$PROXMOX_API_PASSWORD" \
  "$PROXMOX_NODE" 310 --debug
```

**Problem: 401 Authentication failure**

```bash
# Verify token secret is correct
echo "$PROXMOX_API_PASSWORD"  # Should show token secret, not "REPLACE_WITH_..."

# Check token exists
ssh root@proxmox.local "pveum user token list root@pam"

# Recreate token if needed (via Proxmox web UI)
```

### SSH Issues

**Problem: SSH connection refused**

```bash
# Test SSH connectivity
ssh -v root@proxmox.local echo "Connected"

# Check SSH key
ls -la ~/.ssh/id_*
ssh-add -l

# Copy key if needed
ssh-copy-id root@proxmox.local
```

**Problem: Permission denied for qm commands**

```bash
# SSH user must be root or have sudo access
ssh root@proxmox.local "whoami"  # Should return "root"

# Test qm access
ssh root@proxmox.local "qm list"
```

## Testing

### Test API Authentication

```bash
# Test with debug output
cd ~/vm-deploy
source .env
python3 scripts/proxmox_get_vm_ip.py \
  "$PROXMOX_API_HOST" "$PROXMOX_API_USER" "$PROXMOX_API_PASSWORD" \
  "$PROXMOX_NODE" 310 --debug
```

**Expected output:**
```
Using API token authentication for root@pam!syslogapi
192.168.1.100
```

### Test SSH Access

```bash
# Test basic SSH
ssh root@proxmox.local "hostname"

# Test qm commands
ssh root@proxmox.local "qm list"
ssh root@proxmox.local "qm status 310"
```

### Test Full Workflow

```bash
# 1. Check API token permissions
make check-token

# 2. Generate inventory (uses API)
./generate-inventory.sh

# 3. Deploy VMs (uses SSH for disk operations)
make deploy

# 4. Check VM status (uses API)
python3 scripts/proxmox_get_vm_ip.py \
  "$PROXMOX_API_HOST" "$PROXMOX_API_USER" "$PROXMOX_API_PASSWORD" \
  "$PROXMOX_NODE" 200 --debug
```

## Best Practices

### 1. Use API Tokens for Automation

```bash
# ✅ Good - API token with limited permissions
PROXMOX_API_USER="root@pam!deployment"
PROXMOX_API_PASSWORD="secret-token-value"

# ⚠️ Avoid - root password in plaintext
PROXMOX_API_USER="root@pam"
PROXMOX_API_PASSWORD="my-root-password"
```

### 2. Secure Your .env File

```bash
# Set restrictive permissions
chmod 600 .env

# Never commit .env to git
echo ".env" >> .gitignore

# Use separate tokens for dev/prod
# dev: root@pam!dev-token
# prod: root@pam!prod-token
```

### 3. Separate API and SSH Access

```bash
# API token for monitoring/status checks (frequent)
PROXMOX_API_USER="root@pam!monitoring"

# SSH key for deployment (infrequent)
PROXMOX_SSH_USER="root"
```

### 4. Monitor API Usage

```bash
# Check API token activity in Proxmox
# Datacenter → System → Tasks → Filter by token user

# Enable audit logging
ssh root@proxmox.local "pveum user token info root@pam tokenid"
```

## Future Improvements

When Proxmox adds API support for disk operations:

1. **Watch for**: Proxmox VE 9.x+ API enhancements
2. **Tracking**: [Proxmox Bugzilla - Feature Requests](https://bugzilla.proxmox.com/)
3. **Update strategy**: Gradually migrate disk operations as API matures

**Candidates for future API migration:**
- `qm importdisk` → `/api2/json/nodes/{node}/qemu/{vmid}/importdisk` (when available)
- Complex `qm set` → Multiple API calls with proper error handling
- Storage detection → API storage capabilities endpoint

## References

- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [API Token Documentation](https://pve.proxmox.com/wiki/User_Management#pveum_tokens)
- [Proxmox Forum - API Discussions](https://forum.proxmox.com/forums/proxmox-ve-api.30/)
- [qemu-guest-agent Documentation](https://pve.proxmox.com/wiki/Qemu-guest-agent)

## Summary

| Operation Type | Method | Reason |
|---------------|---------|---------|
| **Status/Monitoring** | API | Fast, frequent, read-only |
| **Start/Stop/Delete** | API | Simple state changes |
| **IP Detection** | API | Guest agent has native API |
| **VM Creation** | API | Basic operations supported |
| **Disk Import** | SSH | **No API equivalent** |
| **Disk Configuration** | SSH | API too complex/verbose |
| **Storage Detection** | SSH | CLI simpler to parse |
| **Batch Operations** | SSH | Atomic updates needed |

The hybrid approach provides the **best of both worlds**: API where it excels (monitoring, status), SSH where it's required (disk operations).
