# START HERE - OpenSUSE Ceph Cluster Deployment

## ✅ Complete Feature List

All requested features are implemented:

1. ✅ **GitHub SSH Key Import** - Automatic import from GitHub accounts
2. ✅ **System Updates** - Automatic updates during build and deployment
3. ✅ **Avahi Service Discovery** - mDNS/DNS-SD pre-installed
4. ✅ **LLDP Network Discovery** - Network topology discovery
5. ✅ **Ceph-Ready Disks** - Data disks unformatted for Ceph OSD
6. ✅ **Single NVMe Pool** - Simplified storage configuration
7. ✅ **Environment Variables** - All config via environment variables
8. ✅ **Per-VM Memory/CPU** - Configure memory and cores per VM

## Quick Start (3 Commands)

### Using Environment Variables (Recommended)

```bash
# 1. Configure
cp .env.example .env
vim .env  # Set PROXMOX_API_HOST, STORAGE_POOL, MEMORY, CORES, etc.

# 2. Build image (one-time, 15-40 min)
scp -r kiwi/ root@$(grep PROXMOX_API_HOST .env | cut -d= -f2 | tr -d '"'):/root/
# Then on Proxmox: cd /root/kiwi && ./build-image.sh

# 3. Deploy (7-15 min)
./deploy-with-env.sh
```

**Done!** 4 VMs deployed and configured.

## Configuration Options

### Method 1: Environment Variables (.env file)

**Best for**: Automation, CI/CD, multiple environments

```bash
# .env
export PROXMOX_API_HOST="pve.example.com"
export PROXMOX_API_PASSWORD="secret"
export STORAGE_POOL="nvme-pool"
export GITHUB_USERNAME="your-github-username"

# Memory and CPU
export VM_DEFAULT_MEMORY="16384"  # 16GB per VM
export VM_DEFAULT_CORES="4"       # 4 cores per VM

# Override individual VMs
export VM1_MEMORY="32768"  # VM1: 32GB
export VM1_CORES="8"       # VM1: 8 cores
```

### Method 2: YAML Config File

**Best for**: Manual configuration, one-off deployments

```yaml
# vars/vm_config.yml
storage_pool: "nvme-pool"
vm_default_memory: 16384
vm_default_cores: 4

vms:
  - name: "ceph-node1"
    memory: 32768  # Override: 32GB
    cores: 8       # Override: 8 cores
```

## Memory Configuration Examples

```bash
# Small (8GB per VM)
export VM_DEFAULT_MEMORY="8192"

# Medium (16GB per VM)
export VM_DEFAULT_MEMORY="16384"

# Large (32GB per VM) - Default
export VM_DEFAULT_MEMORY="32768"

# X-Large (64GB per VM)
export VM_DEFAULT_MEMORY="65536"

# XX-Large (128GB per VM)
export VM_DEFAULT_MEMORY="131072"
```

## CPU Configuration Examples

```bash
# Light (4 cores)
export VM_DEFAULT_CORES="4"

# Medium (8 cores) - Default
export VM_DEFAULT_CORES="8"

# Heavy (16 cores)
export VM_DEFAULT_CORES="16"

# Max (24 cores)
export VM_DEFAULT_CORES="24"
```

## Per-VM Configuration

Configure each VM individually:

```bash
# In .env:
# Defaults
export VM_DEFAULT_MEMORY="16384"
export VM_DEFAULT_CORES="4"

# VM1: Database server (large)
export VM1_NAME="ceph-db1"
export VM1_MEMORY="65536"   # 64GB
export VM1_CORES="16"       # 16 cores

# VM2: Application server (medium)
export VM2_NAME="ceph-app1"
export VM2_MEMORY="32768"   # 32GB
export VM2_CORES="8"        # 8 cores

# VM3 & VM4: Storage servers (default)
export VM3_NAME="ceph-storage1"
export VM4_NAME="ceph-storage2"
# Uses defaults: 16GB, 4 cores
```

## All Environment Variables

See [ENV_VARS.md](ENV_VARS.md) for complete reference. Key variables:

### Essential
- `PROXMOX_API_HOST` - Your Proxmox hostname
- `PROXMOX_API_PASSWORD` - Proxmox password
- `STORAGE_POOL` - NVMe storage pool name
- `GITHUB_USERNAME` - Your GitHub username (for SSH keys)

### VM Resources
- `VM_DEFAULT_MEMORY` - RAM in MB (default: **32768** = 32GB)
- `VM_DEFAULT_CORES` - CPU cores (default: **8**)
- `VM_DEFAULT_SOCKETS` - CPU sockets (default: 1)

### Storage
- `DATA_DISK_SIZE` - Data disk size (default: 1000G)
- `MON_DISK_SIZE` - **NEW** Mon disk size (default: 100G)

### Per-VM (Replace N with 1-4)
- `VMN_NAME` - Hostname
- `VMN_MEMORY` - RAM override
- `VMN_CORES` - CPU cores override
- `VMN_IP` - IP address

### Storage & Network
- `DATA_DISK_SIZE` - Data disk size (default: 1000G)
- `PRIVATE_BRIDGE` - Cluster network (default: vmbr1)
- `PUBLIC_BRIDGE` - Client network (default: vmbr0)

## Deployment Workflows

### Workflow 1: Simple (Environment Variables)

```bash
cp .env.example .env
vim .env  # Configure
./deploy-with-env.sh
```

### Workflow 2: Manual Control

```bash
source .env
./generate-config.sh
./generate-inventory.sh
ansible-playbook -i inventory.ini deploy-vms.yml
ansible-playbook -i inventory-vms.ini configure-vms.yml
```

### Workflow 3: One-Liner

```bash
PROXMOX_API_HOST=pve.local \
PROXMOX_API_PASSWORD=secret \
STORAGE_POOL=nvme-pool \
VM_DEFAULT_MEMORY=32768 \
VM_DEFAULT_CORES=8 \
./deploy-with-env.sh
```

## What You Get

**4 VMs**, each with:
- OpenSUSE Leap 15.6 (fully updated)
- Your GitHub SSH keys imported
- avahi-daemon (mDNS) running
- lldpd (network discovery) running
- **32GB RAM** (default, configurable: 8GB - 128GB+)
- **8 CPU cores** (default, configurable: 4 - 32+)
- 50GB OS disk (thin provisioned)
- 4 x 1TB data disks (unformatted for Ceph OSD)
- **1 x 100GB mon disk** (NEW - unformatted for Ceph MON)
- Dual network interfaces
- Dual network interfaces

## Documentation

1. **[START_HERE.md](START_HERE.md)** (this file) - Quick start
2. **[ENV_VARS.md](ENV_VARS.md)** - Complete environment variable reference
3. **[README.md](README.md)** - Full documentation
4. **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Detailed walkthrough
5. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Command cheat sheet

## Scripts

- **`deploy-with-env.sh`** - Complete automated deployment
- **`generate-config.sh`** - Generate vm_config.yml from .env
- **`generate-inventory.sh`** - Generate inventory files from .env
- **`full-deploy.sh`** - Alternative deployment script

## Example Deployments

### Small Dev Cluster
```bash
export NUM_VMS="2"
export VM_DEFAULT_MEMORY="8192"   # 8GB
export VM_DEFAULT_CORES="4"
export DATA_DISK_SIZE="500G"
```

### Production Cluster
```bash
export NUM_VMS="4"
export VM_DEFAULT_MEMORY="32768"  # 32GB
export VM_DEFAULT_CORES="8"
export DATA_DISK_SIZE="2000G"     # 2TB per disk
```

### High-Performance Cluster
```bash
export NUM_VMS="4"
export VM_DEFAULT_MEMORY="65536"  # 64GB
export VM_DEFAULT_CORES="16"
export DATA_DISK_SIZE="4000G"     # 4TB per disk
```

### Mixed Workload Cluster
```bash
export VM_DEFAULT_MEMORY="16384"
export VM_DEFAULT_CORES="4"

# Database node
export VM1_MEMORY="65536"
export VM1_CORES="16"

# App node
export VM2_MEMORY="32768"
export VM2_CORES="8"

# Storage nodes (use defaults)
```

## Time Estimates

| Task | Duration |
|------|----------|
| Build image (first time) | 15-40 min |
| Deploy with .env | 7-15 min |
| **Total first deployment** | **22-55 min** |
| **Redeployment** | **7-15 min** |

## Next Steps After Deployment

1. Verify SSH access
2. Check LLDP neighbors: `lldpcli show neighbors`
3. Check Avahi services: `avahi-browse -a`
4. Verify data disks: `lsblk`
5. Deploy Ceph OSDs on /dev/sd{b,c,d,e}

## Ceph Deployment

Data disks are unformatted and ready:

```bash
# Verify data disks
ansible -i inventory-vms.ini ceph_nodes -a "lsblk"

# Deploy Ceph OSDs on data disks
ceph orch daemon add osd ceph-node1:/dev/sdb
ceph orch daemon add osd ceph-node1:/dev/sdc
ceph orch daemon add osd ceph-node1:/dev/sdd
ceph orch daemon add osd ceph-node1:/dev/sde
# Repeat for other nodes

# NEW: Deploy Ceph MON on dedicated disk
# First, format and mount the MON disk on each node
ansible -i inventory-vms.ini ceph_nodes -a "mkfs.ext4 /dev/sdf"
ansible -i inventory-vms.ini ceph_nodes -a "mkdir -p /var/lib/ceph/mon"
ansible -i inventory-vms.ini ceph_nodes -a "mount /dev/sdf /var/lib/ceph/mon"
ansible -i inventory-vms.ini ceph_nodes -a "echo '/dev/sdf /var/lib/ceph/mon ext4 defaults 0 0' >> /etc/fstab"

# Then deploy MON services
ceph orch apply mon ceph-node1,ceph-node2,ceph-node3
```

## Troubleshooting

### Memory Issues
```bash
# Check total memory needed
TOTAL_MEMORY=$((VM_DEFAULT_MEMORY * NUM_VMS))
echo "Total: ${TOTAL_MEMORY}MB = $(($TOTAL_MEMORY / 1024))GB"

# Reduce if needed
export VM_DEFAULT_MEMORY="8192"
./generate-config.sh
```

### Storage Issues
```bash
# Check storage capacity
ssh root@$PROXMOX_API_HOST "pvesm status"

# Use different pool
export STORAGE_POOL="local-lvm"
./generate-config.sh
```

### Configuration Not Applied
```bash
# Regenerate after changes
source .env
./generate-config.sh
./generate-inventory.sh
```

## Support

- Check logs: `journalctl -xe`
- Ansible verbose: `ansible-playbook -i inventory.ini deploy-vms.yml -vvv`
- KIWI logs: `kiwi/build/build.log`
- Environment vars: [ENV_VARS.md](ENV_VARS.md)

---

**Ready to deploy!**

Choose your method:
1. **Quick**: `./deploy-with-env.sh`
2. **Custom**: Edit `.env` then run `./deploy-with-env.sh`
3. **Manual**: Edit `vars/vm_config.yml` and use Ansible directly

All configuration options support both environment variables AND YAML files.
