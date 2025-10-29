# Quick Start Guide

<!-- Copyright (c) 2025 Darren Soothill -->
<!-- Email: darren [at] soothill [dot] com -->
<!-- License: MIT -->

## Super Simple: All-in-One Command

```bash
# 1. Setup configuration
make init && make edit-env

# 2. Build image + deploy VMs (one command!)
make fresh-start CONFIRM_DELETE=true

# 3. Configure VMs (optional)
make configure
```

**That's it! One command does everything: rebuilds image with LLDP/Avahi, removes old VMs, deploys new VMs.**

---

## Complete Workflow (Step by Step)

### First Time Setup (2 minutes)

```bash
# 1. Clone the repository
git clone https://github.com/soothill/vm-deploy.git
cd vm-deploy

# 2. Create configuration from template
make init

# 3. Edit configuration (Proxmox host, storage, VM settings)
make edit-env

# That's it for setup!
```

### Option A: All-in-One (Recommended for fresh start)

```bash
# Build image + deploy VMs in one command (20-50 minutes total)
make fresh-start CONFIRM_DELETE=true
```

**What it does:**
1. Removes old build VM (if exists)
2. Deploys new build VM
3. Builds OpenSUSE image with LLDP/Avahi
4. Removes old VMs (if exist)
5. Deploys new VMs

### Option B: Step by Step

```bash
# Build image (20-45 minutes)
make deploy-build-vm
make build-image-remote

# Deploy VMs (2-5 minutes)
make deploy
```

**What happens automatically:**
1. ✅ Generates `vars/vm_config.yml` from your `.env`
2. ✅ Generates `inventory.ini` from your `.env`
3. ✅ Checks that the OpenSUSE image exists
4. ✅ Checks for existing VMs (warns if found)
5. ✅ Creates VMs on Proxmox
6. ✅ Configures disks (OS + 4 data disks + mon disk)
7. ✅ Configures networking
8. ✅ Starts VMs

### Optional: Configure VMs (5 minutes)

```bash
# Update VM inventory with actual IPs
make edit-vm-inventory

# Run configuration (SSH keys, updates, services)
make configure
```

## That's The Entire Workflow!

```
┌─────────────────────────────────────────────────────────────┐
│                    SIMPLIFIED WORKFLOW                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Setup (once):           make init && make edit-env        │
│                                                             │
│  Build image (once):     make deploy-build-vm              │
│                          make build-image-remote           │
│                                                             │
│  Deploy VMs:             make deploy                       │
│                                                             │
│  Configure (optional):   make configure                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Common Operations

### Change VM Configuration

```bash
# 1. Edit .env (change memory, cores, IDs, etc.)
vim .env

# 2. Deploy (auto-generates configs)
make deploy
```

### Redeploy VMs from Scratch

```bash
# 1. Clean up existing VMs
make cleanup-vms CONFIRM_DELETE=true

# 2. Deploy fresh
make deploy
```

### Remove VMs

```bash
# Quick cleanup (fast)
make cleanup-vms CONFIRM_DELETE=true

# Or graceful removal (slower)
make remove CONFIRM_DELETE=true
```

## Essential Commands

| Command | Purpose |
|---------|---------|
| `make init` | Create .env from template |
| `make edit-env` | Edit configuration |
| `make deploy` | Deploy VMs (auto-generates configs!) |
| `make configure` | Configure deployed VMs |
| `make cleanup-vms CONFIRM_DELETE=true` | Remove all VMs quickly |
| `make list-vms` | List VMs on Proxmox |
| `make test-connection` | Test Ansible connection to Proxmox |

## Important Notes

### Single Source of Truth: `.env` File

**Everything** is configured in `.env`:
- Proxmox connection details
- VM specifications (IDs, memory, cores)
- Storage configuration
- Network settings
- Image paths

You **never** need to edit:
- ❌ `vars/vm_config.yml` (auto-generated from .env)
- ❌ `inventory.ini` (auto-generated from .env)

Just edit `.env` and run `make deploy`!

### ZFS Storage Users

If using ZFS storage, you **must** enable thin provisioning:

```bash
ssh root@proxmox.local
vi /etc/pve/storage.cfg

# Find your ZFS storage and add: sparse 1
zfspool: RaidZ
    pool RaidZ
    content images,rootdir
    sparse 1        # <--- Add this line
    nodes proxmox
```

See [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md) for details.

### Existing VMs Warning

When you run `make deploy`, it will:
1. Check for existing VMs with the same IDs
2. Warn you if any are found
3. Pause for 15 seconds
4. Give you options:
   - Press **Ctrl+C** to cancel and cleanup first
   - Press **ENTER** to continue (skips existing VMs)

**Existing VMs are never modified or overwritten!**

To recreate VMs, you must cleanup first:
```bash
make cleanup-vms CONFIRM_DELETE=true
make deploy
```

## Troubleshooting

### "Out of space" error on ZFS

Enable thin provisioning. See [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md)

### "VM already exists" warning

Either:
- Cleanup and redeploy: `make cleanup-vms CONFIRM_DELETE=true && make deploy`
- Change VM IDs in `.env`

### "Container ID already in use"

Change VM IDs in `.env` to avoid collision with LXC containers.

### SSH connection fails

Check:
```bash
# Test connection
make test-connection

# Check SSH key path in .env
grep SSH_KEY .env

# Test manual SSH
ssh root@proxmox.local
```

### Image not found

Build the image first:
```bash
make deploy-build-vm
make build-image-remote
```

## Cross-Platform Development

**Develop on Mac, Deploy from Linux:**

```bash
# On Mac (development)
vim .env
git add .env
git commit -m "Update VM configuration"
git push

# On Linux (deployment)
cd ~/vm-deploy
git pull
make deploy
```

See [LINUX_DEPLOYMENT.md](LINUX_DEPLOYMENT.md) for details.

## Complete Command Reference

### Setup & Configuration
- `make help` - Show all commands
- `make init` - Create .env from template
- `make edit-env` - Edit .env configuration
- `make update-env` - Update .env with new variables from .env.example

### Image Building
- `make deploy-build-vm` - Deploy OpenSUSE build VM
- `make build-image-remote` - Build image on build VM
- `make remove-build-vm` - Remove build VM
- `make check-image` - Check if image exists on Proxmox

### VM Deployment
- `make deploy` - Deploy VMs (auto-generates configs)
- `make configure` - Configure deployed VMs
- `make remove CONFIRM_DELETE=true` - Remove VMs via Ansible
- `make cleanup-vms CONFIRM_DELETE=true` - Quick cleanup via SSH

### Monitoring & Info
- `make list-vms` - List all VMs on Proxmox
- `make vm-status` - Show status of configured VMs
- `make test-connection` - Test Ansible connection
- `make status` - Show deployment status

## Getting Help

- Full documentation: [README.md](README.md)
- Architecture details: [ARCHITECTURE.md](ARCHITECTURE.md)
- Cleanup procedures: [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md)
- ZFS configuration: [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md)
- Linux deployment: [LINUX_DEPLOYMENT.md](LINUX_DEPLOYMENT.md)

## Key Simplifications

**Before (complicated):**
```bash
vim .env
make generate-config      # Manual!
make generate-inventory   # Manual!
make check-image
make deploy
```

**After (simple):**
```bash
vim .env
make deploy              # Auto-generates everything!
```

**The `.env` file is your single source of truth. Everything else is automatic!**
