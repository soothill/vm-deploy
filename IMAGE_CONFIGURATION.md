# Image Configuration Guide

This guide explains how to configure custom image storage locations for the OpenSUSE KIWI-built image.

## Overview

By default, the system stores the built image at:
```
/var/lib/vz/template/iso/opensuse-leap-custom.qcow2
```

However, you can customize:
- The image storage directory
- The image filename
- The KIWI build directory on Proxmox

## Configuration Variables

Configure these in your `.env` file:

### OPENSUSE_IMAGE_PATH (Recommended)

The full path where the image will be stored on Proxmox.

```bash
# Default location (ISO template storage)
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"

# Alternative: QEMU template storage
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/qemu/opensuse-leap-custom.qcow2"

# Alternative: Custom storage mount
export OPENSUSE_IMAGE_PATH="/mnt/pve/storage/template/opensuse-leap-custom.qcow2"

# Alternative: Different image name
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/my-custom-opensuse.qcow2"
```

### OPENSUSE_IMAGE_NAME (Optional)

Just the filename (without path). Only needed if not using IMAGE_PATH.

```bash
export OPENSUSE_IMAGE_NAME="opensuse-leap-custom.qcow2"

# Or for a custom name
export OPENSUSE_IMAGE_NAME="my-opensuse-image.qcow2"
```

### KIWI_BUILD_DIR (Optional)

Where KIWI builds the image on Proxmox (defaults to `/root/kiwi`).

```bash
# Default
export KIWI_BUILD_DIR="/root/kiwi"

# Alternative location
export KIWI_BUILD_DIR="/opt/kiwi-builds"

# Or on a different storage mount
export KIWI_BUILD_DIR="/mnt/build/kiwi"
```

## Common Storage Locations on Proxmox

### 1. Default ISO Template Storage
```bash
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"
```
- **Location:** Local directory storage
- **Suitable for:** Single node setups
- **Default in Proxmox**

### 2. QEMU Template Storage
```bash
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/qemu/opensuse-leap-custom.qcow2"
```
- **Location:** VM template directory
- **Suitable for:** VM templates and clones

### 3. Custom Storage Mount
```bash
export OPENSUSE_IMAGE_PATH="/mnt/pve/shared-storage/template/opensuse-leap-custom.qcow2"
```
- **Location:** Shared storage (NFS, Ceph, etc.)
- **Suitable for:** Clustered Proxmox environments
- **Benefits:** Accessible from multiple nodes

### 4. ZFS Storage
```bash
export OPENSUSE_IMAGE_PATH="/mnt/pve/zfs-pool/template/opensuse-leap-custom.qcow2"
```
- **Location:** ZFS pool
- **Suitable for:** High-performance local storage
- **Benefits:** Snapshots, compression

## Usage Examples

### Example 1: Default Configuration

```bash
# .env file
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"
```

```bash
# Build and deploy
make upload-kiwi
make build-image
make deploy
```

### Example 2: Custom Storage Location

```bash
# .env file
export OPENSUSE_IMAGE_PATH="/mnt/pve/shared-storage/templates/opensuse-leap.qcow2"
export KIWI_BUILD_DIR="/mnt/pve/shared-storage/kiwi-build"
```

```bash
# The Makefile will automatically use these paths
make upload-kiwi    # Uploads to /mnt/pve/shared-storage/kiwi-build
make build-image    # Builds and saves to /mnt/pve/shared-storage/templates/
make check-image    # Verifies at the custom location
```

### Example 3: Multiple Image Versions

Build different versions by changing the image name:

```bash
# For development
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-dev.qcow2"
make build-image

# For production
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-prod.qcow2"
make build-image
```

### Example 4: Cluster Setup with Shared Storage

```bash
# .env file for clustered environment
export OPENSUSE_IMAGE_PATH="/mnt/pve/cephfs/templates/opensuse-leap-custom.qcow2"
export KIWI_BUILD_DIR="/mnt/pve/cephfs/kiwi-build"
export STORAGE_POOL="cephfs"
```

Benefits:
- Image accessible from all cluster nodes
- Build directory on shared storage
- No need to copy images between nodes

## Verifying Configuration

### Check Current Settings

```bash
make status
```

Output shows:
```
Image:
  Path: /var/lib/vz/template/iso/opensuse-leap-custom.qcow2
  Name: opensuse-leap-custom.qcow2
```

### Show Detailed Configuration

```bash
make info
```

Output includes:
```
Image Configuration:
  Image Path: /var/lib/vz/template/iso/opensuse-leap-custom.qcow2
  Image Name: opensuse-leap-custom.qcow2
  Build Directory: /root/kiwi
```

### Verify Image Exists

```bash
make check-image
```

## Build Process with Custom Paths

When you run `make build-image`, the system:

1. **Uploads KIWI files** to `$(KIWI_BUILD_DIR)` on Proxmox
2. **Runs KIWI build** in that directory
3. **Saves image** to `$(OPENSUSE_IMAGE_PATH)`

The build script automatically:
- Creates the output directory if needed
- Extracts directory and filename from IMAGE_PATH
- Validates the configuration

## Troubleshooting

### Image Not Found After Build

Check the actual location:

```bash
# SSH to Proxmox
ssh root@proxmox

# List common template directories
ls -lh /var/lib/vz/template/iso/
ls -lh /var/lib/vz/template/qemu/

# Check your custom path
ls -lh /mnt/pve/your-storage/template/
```

### Permission Issues

Ensure the output directory is writable:

```bash
# On Proxmox
mkdir -p /path/to/your/directory
chmod 755 /path/to/your/directory
```

### Wrong Path in vm_config.yml

The `vars/vm_config.yml` must match your `.env` configuration:

```yaml
# vars/vm_config.yml
opensuse_image_path: "/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"
```

This should match:
```bash
# .env
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"
```

Update with:
```bash
make generate-config  # If you have the generate script
# Or manually edit:
make edit-config
```

## Advanced Configuration

### Using Directory Storage

For directory-based storage in Proxmox:

```bash
# .env
export OPENSUSE_IMAGE_PATH="/mnt/pve/local-dir/template/images/opensuse.qcow2"
```

Make sure the storage is configured in Proxmox:
```bash
pvesm add dir local-dir --path /mnt/pve/local-dir --content images,iso,vztmpl
```

### Using NFS Storage

```bash
# .env
export OPENSUSE_IMAGE_PATH="/mnt/pve/nfs-storage/template/opensuse-leap.qcow2"
export KIWI_BUILD_DIR="/mnt/pve/nfs-storage/kiwi-build"
```

### Temporary Build Directory

Use a faster local disk for building, then copy to final location:

```bash
# .env
export KIWI_BUILD_DIR="/tmp/kiwi-build"  # Fast local disk
export OPENSUSE_IMAGE_PATH="/mnt/pve/slow-storage/template/opensuse.qcow2"
```

The build script handles the copy automatically.

## Best Practices

1. **Use Full Paths:** Always specify complete paths including filename
   ```bash
   # Good
   export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"

   # Avoid
   export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/"  # Missing filename
   ```

2. **Verify Before Deploy:** Always run `make check-image` before deploying VMs

3. **Match vm_config.yml:** Ensure your Ansible vars match your `.env` settings

4. **Use Shared Storage for Clusters:** In multi-node setups, use shared storage

5. **Document Custom Paths:** If using non-standard paths, document them in your `.env`

6. **Test Permissions:** Verify write permissions before building

## Environment Variable Priority

The system uses this priority:

1. **IMAGE_PATH** environment variable (highest priority)
2. **IMAGE_NAME** + default directory
3. Default values (`opensuse-leap-custom.qcow2` in `/var/lib/vz/template/iso/`)

Example:
```bash
# This combination:
export OPENSUSE_IMAGE_PATH="/custom/path/my-image.qcow2"
export OPENSUSE_IMAGE_NAME="other-name.qcow2"  # Ignored

# Results in: /custom/path/my-image.qcow2
```

## Summary

**Minimal Configuration (defaults):**
```bash
# No configuration needed - uses defaults
make build-image
```

**Custom Location:**
```bash
# .env
export OPENSUSE_IMAGE_PATH="/your/custom/path/image-name.qcow2"
export KIWI_BUILD_DIR="/your/build/directory"
```

**Verify:**
```bash
make status          # Quick check
make info            # Detailed info
make check-image     # Verify image exists
```

For more help:
- Run `make help` for available commands
- See [README.md](README.md) for general usage
- See [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) for Makefile details
