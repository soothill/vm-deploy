# Architecture and Design Decisions

## Overview

This project deploys OpenSUSE VMs on Proxmox for a Ceph cluster using Ansible, KIWI image builder, and a **hybrid approach** combining Proxmox API and CLI commands.

## Key Design Decision: Hybrid API/CLI Approach

**Operations use Proxmox API where practical, CLI commands where necessary.**

### Why Hybrid Instead of Pure API?

Originally attempted pure API approach with `community.general.proxmox_kvm`, but Proxmox API has technical limitations:

**Proxmox API Limitations:**
1. ❌ No `importdisk` API endpoint - **must use CLI**
2. ❌ No storage type detection API - CLI is simpler
3. ❌ Complex disk configuration requires multiple API calls - CLI is atomic
4. ❌ Boot order and cloud-init device setup better via CLI
5. ❌ Some operations require `proxmoxer` Python library on control machine

**Hybrid Approach Benefits:**
1. ✅ Use API for frequent operations (monitoring, IP detection, status)
2. ✅ Use CLI for deployment (disk import, complex configs)
3. ✅ Zero dependencies on Proxmox host
4. ✅ API token authentication for monitoring (secure, auditable)
5. ✅ SSH for one-time deployment (simpler, more reliable)
6. ✅ Best of both worlds

### Operations by Method

**Proxmox API (via Python scripts):**
- ✅ VM IP detection (`scripts/proxmox_get_vm_ip.py`)
- ✅ Guest agent queries (`library/proxmox_api.py`)
- ✅ VM status checks
- ✅ Inventory generation
- ✅ Start/stop/delete (when used standalone)

**SSH + qm CLI (via Ansible):**
- ⚠️ VM deployment (`qm create`, `qm importdisk`, `qm set`)
- ⚠️ Disk import and configuration (no API equivalent)
- ⚠️ Storage type detection (`pvesm status`)
- ⚠️ Cloud-init device setup
- ⚠️ Batch configuration operations

See [API_USAGE.md](API_USAGE.md) for detailed explanation of when API vs CLI is used.

### Authentication Methods

**API Token (for monitoring):**
```bash
export PROXMOX_API_USER="root@pam!tokenid"
export PROXMOX_API_PASSWORD="token-secret"
```
- Used by: IP detection, status checks, inventory generation
- Benefits: Secure, granular permissions, revocable
- Setup: `make fix-token`

**SSH Keys (for deployment):**
```bash
export PROXMOX_SSH_USER="root"
# SSH key auto-detected (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)
```
- Used by: VM deployment, disk operations, image building
- Benefits: Standard, reliable, no API limitations
- Setup: `ssh-copy-id root@proxmox.local`

### Conversion History

| Component | Method | Reason |
|-----------|--------|--------|
| IP Detection | API | Frequent operation, native guest agent API |
| VM Status | API | Read-only, perfect for API |
| VM Deployment | CLI | Disk import has no API equivalent |
| VM Removal | CLI | Ansible playbook, batch operations |
| Inventory Gen | API | Frequent, benefits from API speed |

## Architecture Components

### 1. Control Machine (Linux/Mac)
- Runs Ansible playbooks
- Stores configuration in `.env` file
- Requires: Ansible, SSH access to Proxmox, Python 3 (for API scripts)
- Python libraries: `requests` (for API client scripts only)
- **Does NOT** require proxmoxer or Proxmox-specific libraries

### 2. Proxmox Host
- Target for VM deployment
- Stores VM images and disks
- Provides API endpoint: `https://proxmox.local:8006/api2/json`
- Requires: SSH access (for deployment), API token (for monitoring)
- **Does NOT** require Python libraries or additional packages
- Operations via: Proxmox API (status/monitoring) and native `qm` CLI (deployment)

### 3. Build VM (Optional but Recommended)
- Dedicated OpenSUSE VM for KIWI image building
- Runs on Proxmox
- Builds custom OpenSUSE images with cloud-init
- Transfers images back to Proxmox storage

### 4. Deployed VMs (Ceph Nodes)
- OpenSUSE Leap with cloud-init
- Configured by Ansible after deployment
- Require: Python 3, zypper (standard OpenSUSE)

## Communication Flow

```
┌─────────────────────────┐
│   Control Machine       │
│   (Linux/Mac)           │
│                         │
│ - Ansible playbooks     │
│ - Python API scripts    │
│ - .env configuration    │
└──────┬──────────┬───────┘
       │ API      │ SSH
       │ (HTTPS)  │
       │          │
       ▼          ▼
┌──────────────────────────────────────┐
│ Proxmox Host                         │
│                                      │
│ API Endpoint (Port 8006):            │
│ ✅ GET /nodes/{node}/qemu/{vmid}/    │
│    agent/network-get-interfaces      │
│ ✅ GET /nodes/{node}/qemu/{vmid}/    │
│    status/current                    │
│ ✅ POST /nodes/{node}/qemu/{vmid}/   │
│    status/start                      │
│                                      │
│ SSH Commands (Port 22):              │
│ ⚠️  qm create (VM creation)          │
│ ⚠️  qm importdisk (no API)           │
│ ⚠️  qm set (complex configs)         │
│ ⚠️  pvesm status (storage detect)    │
│                    │                 │
│                    │ Images          │
│                    ▼                 │
│          ┌──────────────────┐        │
│          │ Build VM         │        │
│          │ (OpenSUSE)       │        │
│          │                  │        │
│          │ - KIWI builder   │        │
│          │ - Image transfer │        │
│          └──────────────────┘        │
│                                      │
│ Deployed VMs:                        │
│ ┌──────────────┐ ┌──────────────┐   │
│ │ Ceph Node 1  │ │ Ceph Node 2  │   │
│ │ (OpenSUSE)   │ │ (OpenSUSE)   │   │
│ │ + qemu-agent │ │ + qemu-agent │   │
│ └──────────────┘ └──────────────┘   │
│      ...                             │
└──────────────────────────────────────┘
```

## Storage Backend Support

The deployment automatically detects storage type and uses appropriate syntax:

### ZFS Storage (e.g., RaidZ)
- **Thin Provisioning**: Controlled by `sparse 1` in `/etc/pve/storage.cfg`
- **Syntax**: `pool:size` (no format, no 'G' suffix)
- **Example**: `RaidZ:1000,discard=on`
- **Note**: Must enable `sparse 1` in storage config for thin provisioning

### LVM-thin Storage
- **Thin Provisioning**: Native to LVM-thin
- **Syntax**: `pool:size` (no format parameter)
- **Example**: `pve:1000G,discard=on,cache=writeback`

### Directory/NFS Storage
- **Thin Provisioning**: Via qcow2 format (default)
- **Syntax**: `pool:size,format=qcow2`
- **Example**: `local:1000G,format=qcow2,discard=on,cache=writeback`

## Disk Layout

Each deployed VM has:

| Disk | Device | Size | Purpose | Thin Provisioned |
|------|--------|------|---------|------------------|
| OS | scsi0 | 50GB | Boot disk | Yes |
| Data 1 | scsi1 | Configurable | Ceph OSD | Yes |
| Data 2 | scsi2 | Configurable | Ceph OSD | Yes |
| Data 3 | scsi3 | Configurable | Ceph OSD | Yes |
| Data 4 | scsi4 | Configurable | Ceph OSD | Yes |
| Mon | scsi5 | 100GB | Ceph MON data | Yes |

**Note**: Data and mon disks are left unformatted for Ceph to manage.

## Configuration Management

### Single Source of Truth: `.env` File

All configuration is stored in `.env` file:
- Proxmox connection details
- VM specifications (IDs, memory, cores)
- Storage configuration
- Network settings
- Image paths

### Generated Files

From `.env`, these files are auto-generated:
- `vars/vm_config.yml` - Ansible variables
- `inventory.ini` - Proxmox host inventory
- `inventory-vms.ini` - VM inventory (after deployment)

**Workflow:**
```bash
# 1. Edit configuration
vim .env

# 2. Generate Ansible configs
make generate-config
make generate-inventory

# 3. Deploy
make deploy
```

## Security Considerations

### API Token Authentication
- Recommended for monitoring and status operations
- Token format: `root@pam!tokenid` with secret
- Granular permissions via PVEVMAdmin role
- Revocable without password changes
- Separate audit trail from SSH operations
- Setup: `make fix-token`

### SSH Key Authentication
- Required for deployment operations (disk import, etc.)
- All SSH access via keys (no password)
- Key path auto-detected or configured in `.env`
- Used for: VM deployment, image building, disk operations

### No Credentials in Git
- `.env` file is gitignored
- `.env.example` provides template
- API tokens and SSH keys never committed
- Each environment has separate credentials

### Minimal Dependencies
- No Python libraries on Proxmox reduces attack surface
- Only standard Proxmox tools used on host
- API scripts run on control machine only
- All operations auditable via Proxmox logs and API access logs

## Error Handling

### VM ID Collision Detection
- Checks both VMs (`qm status`) and Containers (`pct status`)
- Proxmox shares ID namespace between VMs and containers
- Fails early with clear error message

### Storage Space Management
- Requires thin provisioning configuration
- Validates image exists before deployment
- Provides clear documentation for storage setup

### Idempotent Operations
- VM creation checks if VM exists first
- Disk operations skip if already configured
- Network configuration can be reapplied safely

## Testing and Development

### Development Workflow
- Develop on Mac (edit code, test locally)
- Deploy from Linux (network access to Proxmox)
- All changes committed to Git
- Linux machine pulls and deploys

### Cleanup Operations
Two methods for removing VMs:

1. **Fast Cleanup**: `make cleanup-vms CONFIRM_DELETE=true`
   - Direct SSH qm commands
   - Fastest method
   - Best for development/testing

2. **Ansible Cleanup**: `make remove CONFIRM_DELETE=true`
   - Uses remove-vms.yml playbook
   - More controlled/logged
   - Best for production

## Dependencies Summary

### Control Machine (Where Ansible Runs)
- Ansible 2.9+
- Python 3 with `requests` library (for API scripts)
- SSH client
- GNU Make
- Bash

### Proxmox Host
- Proxmox VE (any recent version)
- SSH server (standard)
- API endpoint enabled (default)
- **No additional Python libraries needed on host**

### Build VM (Optional)
- OpenSUSE Leap
- KIWI image builder
- Python 3, git, make

### Deployed VMs
- Python 3 (standard in OpenSUSE)
- qemu-guest-agent (included in custom image)
- Cloud-init (included in custom image)

## Related Documentation

- [README.md](README.md) - Getting started guide
- **[API_USAGE.md](API_USAGE.md)** - API vs CLI usage guide
- [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md) - Storage configuration
- [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md) - VM cleanup procedures
- [LINUX_DEPLOYMENT.md](LINUX_DEPLOYMENT.md) - Cross-platform development
- [IMAGE_CONFIGURATION.md](IMAGE_CONFIGURATION.md) - Custom image paths
