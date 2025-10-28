# Architecture and Design Decisions

## Overview

This project deploys OpenSUSE VMs on Proxmox for a Ceph cluster using Ansible, KIWI image builder, and direct CLI commands.

## Key Design Decision: Pure CLI Approach

**All Proxmox operations use `qm` CLI commands via SSH, not API-based Ansible modules.**

### Why CLI Instead of API?

Originally, the project used `community.general.proxmox_kvm` Ansible module, but this approach had critical issues:

**Problems with API Approach:**
1. Requires `proxmoxer` Python library installed on Proxmox host
2. Requires `requests` Python library on Proxmox host
3. Adds external dependencies to production server
4. Installation requires pip/Python package management on Proxmox
5. Version compatibility issues between Proxmox Python and module requirements

**Benefits of CLI Approach:**
1. ✅ Zero dependencies - `qm` is built into Proxmox
2. ✅ Always available and version-matched to Proxmox
3. ✅ Works immediately via SSH
4. ✅ Better error messages from native tools
5. ✅ Easier debugging (can test commands manually)
6. ✅ More reliable for complex operations (disk management, networking)
7. ✅ No library version conflicts

### Conversion History

All playbooks have been converted from API to CLI:

| Playbook | Original | Current | Commands Used |
|----------|----------|---------|---------------|
| deploy-vms.yml | proxmox_kvm | qm CLI | create, set, importdisk, start |
| remove-vms.yml | proxmox_kvm | qm CLI | stop, destroy |
| configure-vms.yml | N/A | Direct modules | Runs on VMs, not Proxmox |

## Architecture Components

### 1. Control Machine (Linux/Mac)
- Runs Ansible playbooks
- Stores configuration in `.env` file
- Requires: Ansible, SSH access to Proxmox
- **Does NOT** require proxmoxer or requests

### 2. Proxmox Host
- Target for VM deployment
- Stores VM images and disks
- Requires: SSH access, standard Proxmox installation
- **Does NOT** require Python libraries (proxmoxer, requests)
- All operations via native `qm`, `pvesm`, `qm guest cmd` tools

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
┌─────────────────┐
│ Control Machine │
│ (Linux/Mac)     │
│                 │
│ - Ansible       │
│ - .env config   │
└────────┬────────┘
         │ SSH
         ├──────────────────────────────────┐
         │                                  │
         ▼                                  ▼
┌────────────────────┐            ┌──────────────────┐
│ Proxmox Host       │            │ Build VM         │
│                    │            │ (OpenSUSE)       │
│ Operations:        │            │                  │
│ - qm create        │            │ - KIWI build     │
│ - qm set           │            │ - Image transfer │
│ - qm importdisk    │◄───────────┤                  │
│ - qm start         │   Images   │                  │
│ - qm stop          │            │                  │
│ - qm destroy       │            └──────────────────┘
│                    │
│ Creates VMs:       │
│ ┌──────────────┐   │
│ │ Ceph Node 1  │   │
│ │ (OpenSUSE)   │   │
│ └──────────────┘   │
│ ┌──────────────┐   │
│ │ Ceph Node 2  │   │
│ │ (OpenSUSE)   │   │
│ └──────────────┘   │
│      ...           │
└────────────────────┘
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

### SSH Key Authentication
- All Proxmox access via SSH keys (no password)
- Key path configured in `.env`
- Same key used for Ansible and manual operations

### No Credentials in Git
- `.env` file is gitignored
- `.env.example` provides template
- Each user maintains their own credentials

### Minimal Dependencies
- No Python libraries on Proxmox reduces attack surface
- Only standard Proxmox tools used
- All operations auditable via Proxmox logs

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
- SSH client
- GNU Make
- Bash

### Proxmox Host
- Proxmox VE (any recent version)
- SSH server (standard)
- **No additional Python libraries needed**

### Build VM (Optional)
- OpenSUSE Leap
- KIWI image builder
- Python 3, git, make

### Deployed VMs
- Python 3 (standard in OpenSUSE)
- Cloud-init (included in custom image)

## Related Documentation

- [README.md](README.md) - Getting started guide
- [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md) - Storage configuration
- [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md) - VM cleanup procedures
- [LINUX_DEPLOYMENT.md](LINUX_DEPLOYMENT.md) - Cross-platform development
- [IMAGE_CONFIGURATION.md](IMAGE_CONFIGURATION.md) - Custom image paths
