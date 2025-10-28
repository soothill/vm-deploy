# FINAL DEPLOYMENT CONFIGURATION

## Complete VM Specifications

### Default Configuration (Per VM)

**Compute Resources:**
- **RAM**: 32GB (32768 MB)
- **CPU Cores**: 8
- **CPU Sockets**: 1

**Storage:**
- **OS Disk** (scsi0): 50GB - Thin provisioned, formatted ext4
- **OSD Data Disk 1** (scsi1): 1TB - Unformatted for Ceph OSD
- **OSD Data Disk 2** (scsi2): 1TB - Unformatted for Ceph OSD
- **OSD Data Disk 3** (scsi3): 1TB - Unformatted for Ceph OSD
- **OSD Data Disk 4** (scsi4): 1TB - Unformatted for Ceph OSD
- **MON Disk** (scsi5): 100GB - Unformatted for Ceph MON

**Network:**
- **eth0**: Private/cluster network (vmbr1)
- **eth1**: Public/client network (vmbr0)

**Software:**
- OpenSUSE Leap 15.6 (fully updated via zypper)
- GitHub SSH keys (auto-imported)
- avahi-daemon (mDNS service discovery)
- lldpd (network topology discovery)
- QEMU guest agent
- cloud-init

### Total Per VM
- **RAM**: 32GB
- **CPU**: 8 cores
- **Storage**: 4.15TB (50GB OS + 4TB data + 100GB mon)

### Total Cluster (4 VMs)
- **RAM**: 128GB
- **CPU**: 32 cores
- **Storage**: 16.6TB

## Environment Variables - Complete List

### Proxmox Connection
```bash
export PROXMOX_API_USER="root@pam"
export PROXMOX_API_PASSWORD="your_password"
export PROXMOX_API_HOST="proxmox.example.com"
export PROXMOX_NODE="pve"
```

### GitHub SSH Keys
```bash
export GITHUB_USERNAME="your-github-username"
```

### Storage Configuration
```bash
export STORAGE_POOL="nvme-pool"
export DATA_DISK_SIZE="1000G"     # Per OSD disk
export MON_DISK_SIZE="100G"       # MON disk size
```

### Network Configuration
```bash
export PRIVATE_BRIDGE="vmbr1"     # Cluster network
export PUBLIC_BRIDGE="vmbr0"      # Client network
```

### VM Defaults
```bash
export VM_DEFAULT_MEMORY="32768"  # 32GB RAM
export VM_DEFAULT_CORES="8"       # 8 CPU cores
export VM_DEFAULT_SOCKETS="1"
export VM_CPU_TYPE="host"
export AUTO_START="true"
export NUM_VMS="4"
```

### Per-VM Overrides (Example)
```bash
# VM1 - High-performance node
export VM1_NAME="ceph-node1"
export VM1_VMID="200"
export VM1_MEMORY="65536"         # 64GB
export VM1_CORES="16"             # 16 cores
export VM1_IP="192.168.1.10"

# VM2 - Standard node
export VM2_NAME="ceph-node2"
export VM2_VMID="201"
export VM2_MEMORY="32768"         # 32GB (default)
export VM2_CORES="8"              # 8 cores (default)
export VM2_IP="192.168.1.11"
```

## Deployment Commands

### Quick Deployment
```bash
# 1. Configure
cp .env.example .env
vim .env

# 2. Deploy
./deploy-with-env.sh
```

### Manual Deployment
```bash
# 1. Generate configuration
./generate-config.sh
./generate-inventory.sh

# 2. Deploy VMs
ansible-playbook -i inventory.ini deploy-vms.yml

# 3. Configure VMs
ansible-playbook -i inventory-vms.ini configure-vms.yml
```

## Disk Usage Guide

### OSD Data Disks (/dev/sdb, sdc, sdd, sde)
```bash
# Deploy as Ceph OSDs
ceph orch daemon add osd <hostname>:/dev/sdb
ceph orch daemon add osd <hostname>:/dev/sdc
ceph orch daemon add osd <hostname>:/dev/sdd
ceph orch daemon add osd <hostname>:/dev/sde
```

### MON Disk (/dev/sdf)
```bash
# Format and mount for Ceph MON
mkfs.ext4 /dev/sdf
mkdir -p /var/lib/ceph/mon
mount /dev/sdf /var/lib/ceph/mon
echo "/dev/sdf /var/lib/ceph/mon ext4 defaults 0 0" >> /etc/fstab

# Deploy Ceph MON
ceph orch apply mon <hostname>
```

## Memory Configurations

```bash
# Development (8GB)
export VM_DEFAULT_MEMORY="8192"

# Standard (16GB)
export VM_DEFAULT_MEMORY="16384"

# Production (32GB) - DEFAULT
export VM_DEFAULT_MEMORY="32768"

# High-Performance (64GB)
export VM_DEFAULT_MEMORY="65536"

# Enterprise (128GB)
export VM_DEFAULT_MEMORY="131072"
```

## CPU Configurations

```bash
# Light (4 cores)
export VM_DEFAULT_CORES="4"

# Standard (8 cores) - DEFAULT
export VM_DEFAULT_CORES="8"

# Heavy (16 cores)
export VM_DEFAULT_CORES="16"

# Max (24 cores)
export VM_DEFAULT_CORES="24"

# Enterprise (32 cores)
export VM_DEFAULT_CORES="32"
```

## Storage Configurations

```bash
# Smaller OSD disks
export DATA_DISK_SIZE="500G"

# Standard OSD disks - DEFAULT
export DATA_DISK_SIZE="1000G"

# Large OSD disks
export DATA_DISK_SIZE="2000G"

# Extra large OSD disks
export DATA_DISK_SIZE="4000G"

# MON disk sizes
export MON_DISK_SIZE="50G"   # Small
export MON_DISK_SIZE="100G"  # DEFAULT
export MON_DISK_SIZE="200G"  # Large
```

## Network Discovery

### LLDP (Network Topology)
```bash
# View neighbors
lldpcli show neighbors

# Detailed view
lldpcli show neighbors details

# Statistics
lldpcli show statistics
```

### Avahi (Service Discovery)
```bash
# Browse all services
avahi-browse -a

# Browse SSH services
avahi-browse -r _ssh._tcp

# Resolve hostname
avahi-resolve -n <hostname>.local
```

## Verification Commands

### Check VM Resources
```bash
# Memory
ansible -i inventory-vms.ini ceph_nodes -a "free -h"

# CPU
ansible -i inventory-vms.ini ceph_nodes -a "nproc"

# Disks
ansible -i inventory-vms.ini ceph_nodes -a "lsblk"
```

### Check Services
```bash
# All services
ansible -i inventory-vms.ini ceph_nodes -a "systemctl status avahi-daemon lldpd qemu-guest-agent"

# LLDP neighbors
ansible -i inventory-vms.ini ceph_nodes -a "lldpcli show neighbors"

# Avahi services
ansible -i inventory-vms.ini ceph_nodes -a "avahi-browse -a -t"
```

### Check Disk Status
```bash
# List all disks
ansible -i inventory-vms.ini ceph_nodes -a "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT"

# Check OSD disks are unformatted
ansible -i inventory-vms.ini ceph_nodes -a "blkid /dev/sdb /dev/sdc /dev/sdd /dev/sde"

# Check MON disk is unformatted
ansible -i inventory-vms.ini ceph_nodes -a "blkid /dev/sdf"
```

## Files and Documentation

**Configuration:**
- `.env.example` - Environment variable template
- `vars/vm_config.yml` - YAML configuration
- `inventory.ini` - Proxmox host
- `inventory-vms.ini` - VM inventory

**Scripts:**
- `deploy-with-env.sh` - Complete deployment
- `generate-config.sh` - Generate YAML from env vars
- `generate-inventory.sh` - Generate inventory from env vars
- `full-deploy.sh` - Alternative deployment
- `quick-deploy.sh` - Quick deployment

**Playbooks:**
- `deploy-vms.yml` - VM deployment
- `configure-vms.yml` - Post-deployment config
- `remove-vms.yml` - VM removal

**KIWI:**
- `kiwi/opensuse-leap-minimal.kiwi` - Image definition
- `kiwi/config.sh` - System configuration
- `kiwi/build-image.sh` - Build script

**Documentation:**
- `START_HERE.md` - Quick start guide
- `CHANGELOG.md` - Detailed changes
- `QUICK_UPDATE.md` - Recent updates summary
- `ENV_VARS.md` - Environment variable reference
- `README.md` - Complete documentation
- `DEPLOYMENT_GUIDE.md` - Deployment walkthrough
- `QUICK_REFERENCE.md` - Command reference

## Time Estimates

| Task | Duration |
|------|----------|
| Build image (first time) | 15-40 min |
| Configure .env | 2-5 min |
| Deploy VMs | 2-5 min |
| Configure VMs | 5-10 min |
| **Total first deployment** | **24-60 min** |
| **Redeployment** | **9-20 min** |

## Support and Troubleshooting

### Check Logs
```bash
# VM logs
ansible -i inventory-vms.ini ceph_nodes -a "journalctl -xe"

# Specific service
ansible -i inventory-vms.ini ceph_nodes -a "journalctl -u avahi-daemon"

# Proxmox logs
ssh root@<proxmox> "tail -f /var/log/pve/tasks/active"
```

### Common Issues

**Memory:**
```bash
# Check available memory on Proxmox
ssh root@<proxmox> "free -h"

# Reduce VM memory if needed
export VM_DEFAULT_MEMORY="16384"
./generate-config.sh
```

**Storage:**
```bash
# Check storage capacity
ssh root@<proxmox> "pvesm status"

# Use different pool
export STORAGE_POOL="local-lvm"
./generate-config.sh
```

**GitHub Keys:**
```bash
# Test GitHub connectivity
curl -I https://github.com

# Check keys exist
curl https://github.com/<username>.keys

# Manual import
/usr/local/bin/import-github-keys.sh <username> root
```

## Summary

**Complete VM Setup:**
- ✅ 32GB RAM (configurable)
- ✅ 8 CPU cores (configurable)
- ✅ 50GB OS disk
- ✅ 4 x 1TB OSD data disks
- ✅ 1 x 100GB MON disk
- ✅ Dual network interfaces
- ✅ GitHub SSH keys
- ✅ Automatic updates
- ✅ Service discovery (avahi, lldpd)

**Ready for Ceph deployment with optimal configuration!**
