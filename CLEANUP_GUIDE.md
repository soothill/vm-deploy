# VM Cleanup Guide

## Quick Cleanup Commands

### Option 1: Fast Cleanup via SSH (Recommended)

```bash
# Destroy all VMs quickly using direct SSH commands
make cleanup-vms CONFIRM_DELETE=true
```

**When to use:**
- Quick cleanup of failed deployments
- Starting fresh after configuration changes
- Fixing storage issues before redeployment
- Testing and development

**Advantages:**
- Fast (direct SSH, no Ansible overhead)
- Simple (one command)
- Handles stopped and running VMs

### Option 2: Graceful Removal via Ansible

```bash
# Remove VMs using Ansible playbook
make remove CONFIRM_DELETE=true
```

**When to use:**
- Production environments
- When you need Ansible hooks/notifications
- Graceful shutdown and cleanup

### Option 3: Manual Cleanup

```bash
# Clean up specific VM IDs manually
ssh root@proxmox.local "qm stop 310 && qm destroy 310"
ssh root@proxmox.local "qm stop 311 && qm destroy 311"
ssh root@proxmox.local "qm stop 312 && qm destroy 312"
ssh root@proxmox.local "qm stop 313 && qm destroy 313"
```

## Common Cleanup Scenarios

### Scenario 1: Failed Deployment (Out of Space Error)

If deployment failed due to storage issues:

```bash
# 1. Clean up partial VMs
make cleanup-vms CONFIRM_DELETE=true

# 2. Fix storage configuration (e.g., enable ZFS thin provisioning)
ssh root@proxmox.local
vi /etc/pve/storage.cfg
# Add 'sparse 1' to your ZFS storage

# 3. Redeploy
make deploy
```

### Scenario 2: Configuration Changes

When you change VM IDs, memory, cores, or other settings:

```bash
# 1. Clean up existing VMs
make cleanup-vms CONFIRM_DELETE=true

# 2. Update configuration
vim .env
# Change VM settings

# 3. Regenerate config
make generate-config

# 4. Deploy with new settings
make deploy
```

### Scenario 3: Start Fresh

Complete cleanup of everything:

```bash
# 1. Destroy VMs
make cleanup-vms CONFIRM_DELETE=true

# 2. Remove build VM (if exists)
make remove-build-vm

# 3. Clean up ZFS snapshots (if using ZFS)
ssh root@proxmox.local 'zfs list -t all | grep vm-'
ssh root@proxmox.local 'zfs destroy RaidZ/vm-310-disk-0'  # Repeat for each

# 4. Optionally remove the image
ssh root@proxmox.local 'rm /wdred/iso/template/iso/opensuse-leap-custom.qcow2'

# 5. Start deployment from scratch
make deploy-build-vm
make build-image-remote
make deploy
```

## Checking What Will Be Deleted

Before cleanup, see what VMs exist:

```bash
# List all VMs on Proxmox
make list-vms

# Or manually via SSH
ssh root@proxmox.local 'qm list'

# Check specific VM IDs from your config
grep VMID .env
```

## Safety Features

All cleanup commands require explicit confirmation:

```bash
# ❌ This will fail with error message
make cleanup-vms

# ✅ This will proceed with cleanup
make cleanup-vms CONFIRM_DELETE=true
```

## Post-Cleanup Verification

After cleanup, verify VMs are removed:

```bash
# Check no VMs remain
ssh root@proxmox.local 'qm list'

# Check ZFS volumes (if using ZFS)
ssh root@proxmox.local 'zfs list | grep vm-'

# Check storage usage
ssh root@proxmox.local 'pvesm status'
```

## Troubleshooting Cleanup Issues

### Issue: VM Won't Stop

```bash
# Force stop the VM
ssh root@proxmox.local 'qm stop 310 --skiplock'

# If still stuck, kill the process
ssh root@proxmox.local 'qm unlock 310'
ssh root@proxmox.local 'qm stop 310'
```

### Issue: VM is Locked

```bash
# Unlock the VM
ssh root@proxmox.local 'qm unlock 310'
ssh root@proxmox.local 'qm destroy 310'
```

### Issue: "Configuration file does not exist"

The VM is already deleted, but Proxmox has stale references:

```bash
# List actual VMs
ssh root@proxmox.local 'ls /etc/pve/qemu-server/'

# If VM config doesn't exist, ignore the error
```

### Issue: ZFS Volumes Remain After VM Deletion

```bash
# List orphaned ZFS volumes
ssh root@proxmox.local 'zfs list -t volume | grep vm-'

# Destroy specific volume
ssh root@proxmox.local 'zfs destroy RaidZ/vm-310-disk-1'

# Destroy all volumes for a VM
ssh root@proxmox.local 'for vol in $(zfs list -H -o name | grep vm-310); do zfs destroy $vol; done'
```

### Issue: Disk Still Attached Error

```bash
# Force destroy with disk deletion
ssh root@proxmox.local 'qm destroy 310 --purge --destroy-unreferenced-disks 1'
```

## Cleanup Command Comparison

| Command | Method | Speed | Use Case |
|---------|--------|-------|----------|
| `make cleanup-vms` | SSH | Fast | Development, quick fixes |
| `make remove` | Ansible | Slower | Production, graceful shutdown |
| Manual SSH | SSH | Fastest | Specific VMs, troubleshooting |

## Best Practices

1. **Always check first**: Use `make list-vms` before cleanup
2. **Use confirmation**: Never bypass `CONFIRM_DELETE=true` requirement
3. **Check storage after**: Verify disk space is reclaimed
4. **Clean ZFS snapshots**: ZFS may keep snapshots after VM deletion
5. **Document custom VMs**: If you have non-Ansible VMs, don't accidentally delete them

## Related Documentation

- [ZFS_THIN_PROVISIONING.md](ZFS_THIN_PROVISIONING.md) - Fix storage issues before redeploying
- [README.md](README.md) - Full deployment guide
- [LINUX_DEPLOYMENT.md](LINUX_DEPLOYMENT.md) - Deploying from Linux after Mac development
