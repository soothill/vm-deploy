# OpenSUSE VM Deployment for Ceph Cluster

Fast, automated deployment of OpenSUSE Leap VMs optimized for Ceph storage clusters using Ansible and KIWI.

**Quick Start:** Run `make help` for available commands • See [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) for detailed Makefile usage

## Features

- ✅ Deploy 4 OpenSUSE VMs in 2-5 minutes
- ✅ Pre-built KIWI images with automatic updates
- ✅ **Makefile wrapper for easy Ansible management**
- ✅ **GitHub SSH key import during deployment**
- ✅ **Dual network interfaces** (private + public)
- ✅ Thin-provisioned storage (50GB OS + 4x1TB data)
- ✅ **Data disks left unformatted for Ceph OSD**
- ✅ **avahi-daemon** for mDNS/service discovery
- ✅ **lldpd** for network topology discovery
- ✅ Single NVMe storage pool configuration
- ✅ **Automatic system updates** during image build
- ✅ QEMU guest agent and cloud-init ready

## Quick Start

### Prerequisites

- GNU Make installed
- Ansible 2.9+
- SSH access to Proxmox host
- Python 3 with Ansible control node libraries:
  ```bash
  # Install required Python libraries on your machine (not Proxmox)
  pip3 install --user --break-system-packages proxmoxer requests
  # Or without --break-system-packages on non-Homebrew systems:
  pip3 install --user proxmoxer requests
  ```

### Step 1: Initialize Configuration

```bash
# Create .env file from template
make init

# Edit your configuration
make edit-env
```

**Updating existing configuration:** If you already have a `.env` file and pulled new changes:
```bash
make update-env  # Adds new variables, preserves your values
```
See [ENV_MANAGEMENT.md](ENV_MANAGEMENT.md) for details.

Configure these key settings in [.env](.env.example):
- Proxmox API credentials and host
- **Image storage path** (customize where the image is stored)
- Storage pool and disk sizes
- Network bridges
- VM resource defaults
- GitHub username (optional)

**Need custom image storage?** See [IMAGE_CONFIGURATION.md](IMAGE_CONFIGURATION.md) for detailed configuration options.

### Step 2: Build the OpenSUSE Image (One-Time, 20-45 min)

**RECOMMENDED: Use Dedicated Build VM** (works best)

```bash
# Deploy OpenSUSE build VM (one-time, ~5 min)
make deploy-build-vm

# Build image on the build VM (~15-40 min)
make build-image-remote
```

The build VM approach:
- Creates a dedicated OpenSUSE VM on Proxmox for building
- KIWI works natively on OpenSUSE (full support)
- Builds image and transfers it to Proxmox automatically
- **Auto-detects VM IP via DHCP** - no manual configuration needed
- VM can be reused for future builds
- See [BUILD_VM_GUIDE.md](BUILD_VM_GUIDE.md) for complete guide

**Troubleshooting:** If the IP detection fails, you can manually detect it:
```bash
# Auto-detect and save build VM IP
make detect-build-vm-ip

# Or set manually in .env
export BUILD_VM_IP="192.168.1.x"
```

**Alternative: Direct Build on Proxmox** (legacy method)

```bash
# Build directly on Proxmox host
make upload-kiwi
make build-image
```

Note: Direct build on Proxmox (Debian-based) may have compatibility issues. Build VM method is recommended for production use.

### Step 3: Deploy VMs (2-5 minutes)

```bash
# Test connection first
make test-connection

# Deploy VMs
make deploy
```

Or with options:
```bash
# Verbose deployment
make deploy VERBOSE=2

# Dry-run (check mode)
make deploy CHECK=1
```

### Step 4: Configure VMs (5-10 minutes)

After deployment, update [inventory-vms.ini](inventory-vms.ini) with actual VM IPs, then:

```bash
# Configure VMs (updates, SSH keys, services)
make configure
```

Or deploy and configure in one step:
```bash
make deploy-full
```

This will:
- Import your GitHub SSH keys
- Run zypper update to get latest packages
- Verify avahi-daemon is running
- Verify lldpd is running
- Check data disks are ready for Ceph

## Makefile Commands

See all available commands:
```bash
make help
```

### Main Operations

| Command | Description |
|---------|-------------|
| `make all` | Full deployment (image check + deploy + configure) |
| `make deploy` | Deploy VMs to Proxmox |
| `make configure` | Configure deployed VMs |
| `make deploy-full` | Deploy and configure in one step |
| `make remove CONFIRM_DELETE=true` | Remove VMs (requires confirmation) |

### Image Management

| Command | Description |
|---------|-------------|
| `make build-image` | Build OpenSUSE image on Proxmox |
| `make check-image` | Check if image exists |
| `make upload-kiwi` | Upload KIWI files to Proxmox |

### VM Operations

| Command | Description |
|---------|-------------|
| `make list-vms` | List configured VMs |
| `make vm-status` | Check VM status |
| `make start-vms` | Start all VMs |
| `make stop-vms` | Stop all VMs |

### Testing & Validation

| Command | Description |
|---------|-------------|
| `make test-connection` | Test Proxmox connection |
| `make test-vm-connection` | Test VM connections |
| `make check-syntax` | Check playbook syntax |
| `make dry-run` | Dry-run full deployment |

### Configuration

| Command | Description |
|---------|-------------|
| `make edit-config` | Edit VM configuration |
| `make edit-inventory` | Edit Proxmox inventory |
| `make edit-vm-inventory` | Edit VM inventory |
| `make edit-env` | Edit environment variables |

### Utility

| Command | Description |
|---------|-------------|
| `make status` | Show deployment status |
| `make info` | Show detailed configuration |
| `make update` | Update all VMs |
| `make clean` | Clean generated files |

### Options

Add these options to any command:

```bash
VERBOSE=1/2/3    # Add verbosity (-v/-vv/-vvv)
CHECK=1          # Run in check mode (dry-run)
DIFF=1           # Show differences
CONFIRM_DELETE=true  # Required for remove command
```

Examples:
```bash
make deploy VERBOSE=2
make configure CHECK=1 DIFF=1
make remove CONFIRM_DELETE=true
```

## Alternative: Direct Ansible Usage

If you prefer using Ansible directly without Make:

```bash
# Deploy VMs
ansible-playbook -i inventory.ini deploy-vms.yml

# Configure VMs
ansible-playbook -i inventory-vms.ini configure-vms.yml

# Remove VMs
ansible-playbook -i inventory.ini remove-vms.yml -e "confirm_deletion=true"

# With verbosity
ansible-playbook -i inventory.ini deploy-vms.yml -vvv

# Dry-run
ansible-playbook -i inventory.ini deploy-vms.yml --check
```

## Storage Configuration

### Single NVMe Pool Design

All disks use the same high-performance NVMe storage pool:

```yaml
storage_pool: "nvme-pool"  # Your NVMe storage name
```

### Disk Layout Per VM

- **OS Disk** (scsi0): 50GB thin-provisioned, formatted ext4
- **Data Disk 1** (scsi1): 1TB thin-provisioned, **UNFORMATTED**
- **Data Disk 2** (scsi2): 1TB thin-provisioned, **UNFORMATTED**
- **Data Disk 3** (scsi3): 1TB thin-provisioned, **UNFORMATTED**
- **Data Disk 4** (scsi4): 1TB thin-provisioned, **UNFORMATTED**

**Important**: Data disks are intentionally left unformatted and unmounted for Ceph OSD usage.

## GitHub SSH Key Import

### Automatic Import

Set your GitHub username in `vars/vm_config.yml`:

```yaml
github_username: "your-github-username"
```

Keys will be automatically imported when you run `configure-vms.yml`.

### Manual Import

On any VM:

```bash
/usr/local/bin/import-github-keys.sh your-github-username root
```

### Benefits

- No need to manually copy SSH keys
- Can import keys from multiple GitHub accounts
- Keys are added to existing authorized_keys (non-destructive)

## Network Discovery

### LLDP (Link Layer Discovery Protocol)

Check discovered network neighbors:

```bash
lldpcli show neighbors
lldpcli show neighbors details
```

### Avahi (mDNS/DNS-SD)

Browse available services:

```bash
avahi-browse -a
avahi-resolve -n hostname.local
```

## System Updates

### During Image Build

The KIWI build process automatically runs:
```bash
zypper refresh && zypper update -y
```

### After Deployment

The `configure-vms.yml` playbook runs another update:
```bash
zypper refresh && zypper update -y
```

### Manual Updates

```bash
zypper refresh && zypper update
```

## Ceph Deployment

After VMs are deployed and configured:

### Verify Data Disks

```bash
# Check disks are present and unformatted
lsblk
blkid /dev/sdb /dev/sdc /dev/sdd /dev/sde  # Should show no output
```

### Deploy Ceph OSDs

```bash
# Example with cephadm
ceph orch daemon add osd ceph-node1:/dev/sdb
ceph orch daemon add osd ceph-node1:/dev/sdc
ceph orch daemon add osd ceph-node1:/dev/sdd
ceph orch daemon add osd ceph-node1:/dev/sde
# Repeat for each node
```

## Troubleshooting

### GitHub SSH Key Import Fails

```bash
curl -I https://github.com
/usr/local/bin/import-github-keys.sh your-username root
curl https://github.com/your-username.keys
```

### avahi-daemon Not Running

```bash
systemctl status avahi-daemon
systemctl start avahi-daemon
journalctl -u avahi-daemon
```

### lldpd Not Discovering Neighbors

```bash
systemctl status lldpd
systemctl restart lldpd
# Wait 30 seconds
lldpcli show neighbors
```

## Time Estimates

| Task | Duration |
|------|----------|
| Build image (first time) | 15-40 min |
| Deploy 4 VMs | 2-5 min |
| Configure VMs | 5-10 min |
| **Total** | **20-55 min** |

## Support

For issues:
- **KIWI**: Check `kiwi/build/build.log`
- **Ansible**: Run with `-vvv`
- **Proxmox**: Check `/var/log/pve/`
- **VMs**: Check `journalctl -xe`

---

**Optimized for Ceph Storage Clusters on NVMe**
