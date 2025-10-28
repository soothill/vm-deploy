# Quick Update Summary

## What Changed

### 1. Added Ceph MON Disk ✅
- **NEW**: 100GB dedicated disk for Ceph MON storage
- **Device**: `/dev/sdf` (scsi5)
- **Configurable**: `export MON_DISK_SIZE="100G"`

### 2. Increased Default RAM ✅
- **OLD**: 16GB per VM
- **NEW**: 32GB per VM
- **Variable**: `VM_DEFAULT_MEMORY="32768"`

### 3. Increased Default CPU Cores ✅
- **OLD**: 4 cores per VM
- **NEW**: 8 cores per VM
- **Variable**: `VM_DEFAULT_CORES="8"`

## Complete Disk Layout (Per VM)

```
scsi0: 50GB   - OS disk (formatted ext4)
scsi1: 1TB    - OSD data disk (unformatted)
scsi2: 1TB    - OSD data disk (unformatted)
scsi3: 1TB    - OSD data disk (unformatted)
scsi4: 1TB    - OSD data disk (unformatted)
scsi5: 100GB  - MON disk (NEW - unformatted)
```

## Default VM Specs (Updated)

**Per VM:**
- **RAM**: 32GB (was 16GB)
- **CPU**: 8 cores (was 4 cores)
- **OS Disk**: 50GB
- **OSD Disks**: 4 x 1TB
- **MON Disk**: 100GB (NEW)

**Total per VM**: 4.15TB storage, 32GB RAM, 8 cores

## Quick Start (No Changes)

```bash
# 1. Configure
cp .env.example .env
vim .env  # Now defaults to 32GB RAM, 8 cores

# 2. Build image (one-time)
# (Same as before)

# 3. Deploy
./deploy-with-env.sh
```

## Using the MON Disk

### Mount MON Disk

```bash
# On each node
mkfs.ext4 /dev/sdf
mkdir -p /var/lib/ceph/mon
mount /dev/sdf /var/lib/ceph/mon
echo "/dev/sdf /var/lib/ceph/mon ext4 defaults 0 0" >> /etc/fstab
```

### Or via Ansible

```bash
ansible -i inventory-vms.ini ceph_nodes -a "mkfs.ext4 /dev/sdf"
ansible -i inventory-vms.ini ceph_nodes -a "mkdir -p /var/lib/ceph/mon"
ansible -i inventory-vms.ini ceph_nodes -a "mount /dev/sdf /var/lib/ceph/mon"
```

## Environment Variable Reference

```bash
# New defaults in .env.example:
export VM_DEFAULT_MEMORY="32768"   # 32GB (was 16GB)
export VM_DEFAULT_CORES="8"        # 8 cores (was 4)
export MON_DISK_SIZE="100G"        # NEW - MON disk

# Still configurable per VM:
export VM1_MEMORY="65536"   # VM1: 64GB
export VM1_CORES="16"       # VM1: 16 cores
```

## Backward Compatibility

Want the old defaults? Just override:

```bash
export VM_DEFAULT_MEMORY="16384"  # Back to 16GB
export VM_DEFAULT_CORES="4"       # Back to 4 cores
export MON_DISK_SIZE="50G"        # Smaller MON disk
```

## Total Cluster Resources (4 VMs)

**With new defaults:**
- **Total RAM**: 128GB (was 64GB)
- **Total CPU**: 32 cores (was 16 cores)
- **Total Storage**: 16.6TB
  - OS: 200GB
  - OSD: 16TB
  - MON: 400GB

## Files Updated

- ✅ `.env.example` - New defaults
- ✅ `vars/vm_config.yml` - New defaults
- ✅ `deploy-vms.yml` - MON disk creation
- ✅ `configure-vms.yml` - MON disk verification
- ✅ `generate-config.sh` - MON disk support
- ✅ All documentation

## Documentation

See:
- **CHANGELOG.md** - Detailed changes
- **START_HERE.md** - Updated quick start
- **ENV_VARS.md** - Complete variable reference

## No Breaking Changes

- Same deployment process
- Same commands
- Same configuration methods
- Just better defaults!

---

**Summary**: More RAM (32GB), more cores (8), plus a dedicated 100GB MON disk for better Ceph performance!
