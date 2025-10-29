# ZFS Thin Provisioning Configuration

<!-- Copyright (c) 2025 Darren Soothill -->
<!-- Email: darren [at] soothill [dot] com -->
<!-- License: MIT -->

## Problem

When deploying VMs to ZFS storage, you may encounter "out of space" errors even when plenty of capacity is available. This happens because **ZFS in Proxmox does NOT thin provision by default** - it pre-allocates the full volume size.

### Symptoms:
- Error: `zfs error: cannot create 'RaidZ/vm-XXX-disk-X': out of space`
- Large disk allocations (e.g., 4 VMs × 4 × 1TB = 16TB) fail
- `zfs list` shows volumes consuming full allocated space immediately

## Root Cause

ZFS storage pools in Proxmox require the `sparse` option to be enabled in the storage configuration. Without it, ZFS creates thick (fully pre-allocated) volumes.

## Solution: Enable Thin Provisioning for ZFS Storage

### Step 1: Check Current Configuration

```bash
# On Proxmox host, check storage configuration
cat /etc/pve/storage.cfg | grep -A5 "zfspool: RaidZ"
```

### Step 2: Add sparse=1 to Storage Configuration

Edit the storage configuration:

```bash
# On Proxmox host
vi /etc/pve/storage.cfg
```

Find your ZFS storage pool (e.g., "RaidZ") and add `sparse 1`:

**Before:**
```
zfspool: RaidZ
    pool RaidZ
    content images,rootdir
    nodes proxmox
```

**After:**
```
zfspool: RaidZ
    pool RaidZ
    content images,rootdir
    sparse 1
    nodes proxmox
```

### Step 3: Verify Configuration

```bash
# Check that sparse is now enabled
pvesm status -storage RaidZ

# The output should show the storage with sparse enabled
```

### Step 4: Clean Up and Redeploy

```bash
# Remove any VMs created before enabling sparse
qm destroy 310
qm destroy 311
qm destroy 312
qm destroy 313

# Deploy again with thin provisioning now enabled
cd ~/vm-deploy
make deploy
```

## How Thin Provisioning Works with ZFS

### Without sparse=1 (Thick Provisioning):
- Creating a 1TB volume immediately allocates 1TB of space
- 16TB of volumes = 16TB of actual space consumed
- Fails if physical space is insufficient

### With sparse=1 (Thin Provisioning):
- Creating a 1TB volume only allocates metadata (~few KB)
- Space is allocated on-demand as data is written
- You can over-provision: create 16TB of volumes on 2TB of space
- Actual space consumption grows with actual data written

## Automation: Configure via Ansible

You can also configure this via SSH from your control machine:

```bash
# On your Linux control machine (darren@syslog)
ssh root@proxmox.local

# Add sparse=1 to storage config
if ! grep -q "sparse 1" /etc/pve/storage.cfg; then
    # Backup first
    cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup

    # Add sparse to RaidZ storage
    sed -i '/zfspool: RaidZ/,/^$/s/nodes proxmox/nodes proxmox\n\tsparse 1/' /etc/pve/storage.cfg
fi

# Verify
cat /etc/pve/storage.cfg | grep -A6 "zfspool: RaidZ"
```

## Alternative: Use a Different Storage Pool

If you have an LVM-thin storage pool, it thin provisions by default:

```bash
# In your .env file, change from:
export STORAGE_POOL="RaidZ"

# To your LVM-thin pool:
export STORAGE_POOL="pve"  # or whatever your LVM-thin pool is named
```

Then regenerate config and deploy:
```bash
make generate-config
make deploy
```

## Verification After Configuration

After enabling sparse, verify thin provisioning is working:

```bash
# Create a test VM disk
qm set 999 --scsi0 RaidZ:100

# Check actual space used (should be minimal, not 100GB)
zfs list | grep vm-999-disk-0

# Should show something like:
# RaidZ/vm-999-disk-0  128K  1.50T  128K  -

# Clean up test
qm set 999 --delete scsi0
```

## References

- Proxmox VE Storage Documentation: https://pve.proxmox.com/wiki/Storage
- ZFS Thin Provisioning: https://pve.proxmox.com/wiki/ZFS_on_Linux#sysadmin_zfs_volume_usage
