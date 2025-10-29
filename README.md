# OpenSUSE Ceph Cluster Deployment

Automated deployment of OpenSUSE VMs on Proxmox for Ceph storage cluster.

**🚀 New here? Start with [QUICKSTART.md](QUICKSTART.md)**

## Features

- **Simple workflow** - Edit `.env`, run `make deploy`, done!
- **Auto-configuration** - Never manually edit Ansible files
- **No dependencies** - Pure SSH/CLI, no Python libraries on Proxmox
- **Storage agnostic** - ZFS, LVM-thin, or Directory with thin provisioning
- **Network discovery** - LLDP and Avahi pre-installed
- **Cross-platform** - Develop on Mac, deploy from Linux

## Quick Start

```bash
# 1. Setup
make init && make edit-env

# 2. Build image (one-time, 20-45 min)
make deploy-build-vm && make build-image-remote

# 3. Deploy VMs (2-5 minutes)
make deploy

# 4. Optional: Configure VMs
make configure
```

**That's it!** See [QUICKSTART.md](QUICKSTART.md) for detailed walkthrough.

## Prerequisites

- **Ansible 2.9+** (on your machine)
- **Proxmox access** (choose one):
  - **API Token** (recommended) - For monitoring and IP detection
  - **SSH Keys** - Required for deployment (disk operations)
- **Proxmox VE** (any recent version)
- **Thin provisioning enabled** (see [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md))

### Authentication Setup

This project uses a **hybrid approach**: Proxmox API for monitoring, SSH for deployment.

**Quick setup:**
```bash
# 1. Create API token in Proxmox (recommended)
# Datacenter → Permissions → API Tokens → Add
# Token ID: deployment

# 2. Configure in .env
export PROXMOX_API_USER="root@pam!deployment"
export PROXMOX_API_PASSWORD="your-token-secret"

# 3. Grant permissions
make fix-token

# 4. Setup SSH keys (required for deployment)
ssh-copy-id root@proxmox.local
```

See [API_USAGE.md](API_USAGE.md) for detailed authentication guide.

## Essential Commands

```bash
make deploy                          # Deploy VMs (auto-generates configs)
make configure                       # Configure VMs (optional)
make cleanup-vms CONFIRM_DELETE=true # Remove VMs
make check-token                     # Check API token permissions
make fix-token                       # Fix API token permissions
make list-vms                        # List VMs
make help                            # Show all commands
```

## Configuration

Everything is in `.env`:

```bash
make edit-env    # Edit configuration
make deploy      # Apply changes (auto-generates Ansible configs)
```

**Note:** The `.env` file is your single source of truth. You never need to edit `vars/vm_config.yml` or `inventory.ini` - they're auto-generated!

## VM Layout

Each VM includes:
- **OS disk**: 50GB
- **Data disks**: 4 × 1TB (configurable) for Ceph OSD
- **Mon disk**: 100GB for Ceph MON
- **Networks**: Dual NICs (public/private)
- **Services**: QEMU guest agent, LLDP, Avahi

All disks are thin provisioned. Data/mon disks are unformatted for Ceph.

## Troubleshooting

### API Permission Issues
```bash
# Check API token permissions
make check-token

# Fix missing permissions
make fix-token

# Test API access
source .env && python3 scripts/proxmox_get_vm_ip.py \
  "$PROXMOX_API_HOST" "$PROXMOX_API_USER" "$PROXMOX_API_PASSWORD" \
  "$PROXMOX_NODE" 310 --debug
```

### "Out of space" on ZFS
Enable thin provisioning: [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md)

### "VM already exists"
Run: `make cleanup-vms CONFIRM_DELETE=true && make deploy`

### SSH connection fails
Run: `make test-connection`

### Image not found
Build it: `make deploy-build-vm && make build-image-remote`

See [API_USAGE.md](API_USAGE.md) for comprehensive troubleshooting.

## Documentation

### Start Here
- **[QUICKSTART.md](QUICKSTART.md)** - Complete walkthrough
- **[API_USAGE.md](API_USAGE.md)** - API vs SSH authentication guide
- **[ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md)** - Required for ZFS users!

### Reference
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Hybrid API/CLI design decisions
- **[CLEANUP_GUIDE.md](CLEANUP_GUIDE.md)** - Removal procedures
- **[BUILD_VM_GUIDE.md](BUILD_VM_GUIDE.md)** - Build VM details
- **[LINUX_DEPLOYMENT.md](LINUX_DEPLOYMENT.md)** - Cross-platform workflow

## Complete Example

```bash
# Setup (one-time)
make init
vim .env    # Configure Proxmox, storage, VMs

# Build image (one-time)
make deploy-build-vm
make build-image-remote

# Enable ZFS thin provisioning (if using ZFS)
ssh root@proxmox.local 'echo "sparse 1" >> /etc/pve/storage.cfg'

# Deploy VMs
make deploy

# Done! VMs are ready
```

## Workflow

```
Edit .env → make deploy → Done!
```

The `make deploy` command:
1. Auto-generates `vars/vm_config.yml` from `.env`
2. Auto-generates `inventory.ini` from `.env`
3. Checks image exists
4. Warns about existing VMs
5. Deploys new VMs
6. Configures disks and networking
7. Starts VMs

**Simple. Automatic. Reliable.**

## Support

For detailed help, see [QUICKSTART.md](QUICKSTART.md) and other documentation above.
