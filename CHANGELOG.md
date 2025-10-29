# CHANGELOG - Latest Updates

<!-- Copyright (c) 2025 Darren Soothill -->
<!-- Email: darren [at] soothill [dot] com -->
<!-- License: MIT -->

## Version 2.0 - Enhanced Ceph Cluster Configuration

### Major Changes

#### 1. Added Ceph MON Disk (100GB)
- **NEW**: Each VM now gets a 5th disk dedicated to Ceph MON storage
- **Size**: 100GB (configurable via `MON_DISK_SIZE` or `mon_disk_size`)
- **Location**: `/dev/sdf` (scsi5)
- **Format**: Unformatted, ready for Ceph MON deployment
- **Purpose**: Dedicated disk for Ceph monitor data storage

#### 2. Updated Default VM Resources

**Memory:**
- **OLD**: 16GB (16384 MB)
- **NEW**: 32GB (32768 MB)

**CPU Cores:**
- **OLD**: 4 cores
- **NEW**: 8 cores

These new defaults provide better performance for production Ceph clusters.

### Disk Layout Per VM (Updated)

Each VM now has:
- **scsi0**: 50GB OS disk (thin provisioned, formatted ext4)
- **scsi1**: 1TB data disk (unformatted for Ceph OSD)
- **scsi2**: 1TB data disk (unformatted for Ceph OSD)
- **scsi3**: 1TB data disk (unformatted for Ceph OSD)
- **scsi4**: 1TB data disk (unformatted for Ceph OSD)
- **scsi5**: 100GB mon disk (NEW - unformatted for Ceph MON)

### Total Storage Per VM

- OS: 50GB
- OSD Data: 4TB (4 x 1TB)
- MON Data: 100GB
- **Total**: 4.15TB

### Environment Variables

#### New Variables

```bash
# Ceph MON disk size
export MON_DISK_SIZE="100G"  # Default: 100GB
```

#### Updated Defaults

```bash
# Memory per VM
export VM_DEFAULT_MEMORY="32768"  # Changed from 16384

# CPU cores per VM
export VM_DEFAULT_CORES="8"  # Changed from 4
```

### Configuration Examples

#### Example 1: Using New Defaults (32GB, 8 cores)

```bash
# .env
export PROXMOX_API_HOST="pve.example.com"
export PROXMOX_API_PASSWORD="yourpass"
export STORAGE_POOL="nvme-pool"
# Defaults are now 32GB and 8 cores
# No need to specify if you want these values
```

#### Example 2: Custom MON Disk Size

```bash
# .env
export MON_DISK_SIZE="200G"  # Increase MON disk to 200GB
```

#### Example 3: Mixed Configuration

```bash
# .env
# Use new defaults for most VMs
export VM_DEFAULT_MEMORY="32768"  # 32GB
export VM_DEFAULT_CORES="8"       # 8 cores

# But give one VM more resources
export VM1_MEMORY="65536"   # VM1: 64GB
export VM1_CORES="16"       # VM1: 16 cores
```

#### Example 4: Smaller Environment (Override Defaults)

```bash
# .env
# Override defaults for smaller environment
export VM_DEFAULT_MEMORY="16384"  # Back to 16GB
export VM_DEFAULT_CORES="4"       # Back to 4 cores
export MON_DISK_SIZE="50G"        # Smaller MON disk
```

### Deployment Changes

No changes to deployment process. Same commands work:

```bash
# Method 1: Using environment variables
./deploy-with-env.sh

# Method 2: Using YAML config
ansible-playbook -i inventory.ini deploy-vms.yml
ansible-playbook -i inventory-vms.ini configure-vms.yml
```

### Ceph Deployment with MON Disk

#### Deploy Ceph OSDs (Same as Before)

```bash
# On each node, deploy OSDs on data disks
ceph orch daemon add osd ceph-node1:/dev/sdb
ceph orch daemon add osd ceph-node1:/dev/sdc
ceph orch daemon add osd ceph-node1:/dev/sdd
ceph orch daemon add osd ceph-node1:/dev/sde
```

#### Deploy Ceph MON (NEW - Use Dedicated Disk)

```bash
# Option 1: Let Ceph use the MON disk
# Format and mount the mon disk first
mkfs.ext4 /dev/sdf
mkdir -p /var/lib/ceph/mon
mount /dev/sdf /var/lib/ceph/mon
echo "/dev/sdf /var/lib/ceph/mon ext4 defaults 0 0" >> /etc/fstab

# Then deploy MON
ceph orch apply mon ceph-node1

# Option 2: Use cephadm with custom mon data path
ceph orch daemon add mon ceph-node1 --placement="ceph-node1"
```

### Resource Planning

#### Calculate Total Memory

```bash
# With new defaults (32GB per VM, 4 VMs)
TOTAL_MEMORY=$((32768 * 4))
echo "Total RAM: ${TOTAL_MEMORY}MB = 128GB"
```

#### Calculate Total Storage

```bash
# Per VM: 50GB OS + 4TB data + 100GB mon = 4.15TB
# Total for 4 VMs: 16.6TB
echo "Total Storage: 16.6TB"
```

### Migration from Previous Version

If you have an existing `.env` file or `vm_config.yml`:

#### Option 1: Use New Defaults (Recommended)

```bash
# Just regenerate config
cp .env.example .env.new
# Copy your settings from .env to .env.new
# Use the new defaults (32GB, 8 cores)
mv .env.new .env
./generate-config.sh
```

#### Option 2: Keep Old Settings

```bash
# In your existing .env, explicitly set old values
export VM_DEFAULT_MEMORY="16384"  # Keep 16GB
export VM_DEFAULT_CORES="4"       # Keep 4 cores
export MON_DISK_SIZE="100G"       # Add MON disk

./generate-config.sh
```

### Verification

After deployment, verify the MON disk:

```bash
# On each VM
lsblk | grep sdf
# Should show 100G disk

# Verify it's unformatted
blkid /dev/sdf
# Should return nothing (ready for use)
```

### Documentation Updates

All documentation has been updated to reflect:
- New default memory (32GB)
- New default CPU cores (8)
- New MON disk (100GB on /dev/sdf)

See:
- `START_HERE.md` - Updated quick start
- `ENV_VARS.md` - Updated variable reference
- `README.md` - Updated configuration examples
- `DEPLOYMENT_GUIDE.md` - Updated deployment instructions

### Backward Compatibility

The changes are backward compatible. If you want to use the old defaults:

```bash
export VM_DEFAULT_MEMORY="16384"
export VM_DEFAULT_CORES="4"
# MON disk will still be created at 100GB
# You can reduce it with: export MON_DISK_SIZE="50G"
```

### Files Modified

- `deploy-vms.yml` - Added MON disk creation
- `configure-vms.yml` - Added MON disk verification
- `.env.example` - Updated defaults, added MON_DISK_SIZE
- `vars/vm_config.yml` - Updated defaults, added mon_disk_size
- `generate-config.sh` - Added MON disk support, updated defaults
- All documentation files

### Performance Benefits

With new defaults (32GB RAM, 8 cores):
- Better Ceph OSD performance
- Can handle more concurrent operations
- Improved recovery/rebalancing speed
- Better suited for production workloads

With dedicated MON disk:
- Improved MON performance
- Separate I/O for MON operations
- Better monitoring responsiveness
- Reduced contention with OS disk

### Summary

**What Changed:**
1. ✅ Added 100GB MON disk to each VM (/dev/sdf)
2. ✅ Increased default RAM to 32GB
3. ✅ Increased default CPU cores to 8
4. ✅ Updated all configuration files and documentation

**What Stayed the Same:**
- Deployment process
- Environment variable configuration
- GitHub SSH key import
- Automatic updates
- Avahi and LLDP
- 4 x 1TB data disks for OSD
- Single NVMe storage pool

**Total Resources Per VM (New Defaults):**
- RAM: 32GB (was 16GB)
- CPU: 8 cores (was 4 cores)
- OS Disk: 50GB
- OSD Disks: 4 x 1TB
- MON Disk: 100GB (NEW)
