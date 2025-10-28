# KIWI Setup on Proxmox

This document explains how KIWI is installed on Proxmox systems.

## OS Detection

Proxmox VE is based on Debian, so its `/etc/os-release` reports:
```
ID=debian
VERSION_CODENAME=bookworm (or bullseye)
```

The build script detects this and uses `apt-get` to install KIWI.

## Automatic Installation

When you run `make build-image`, the script:

1. **Detects the OS** by reading `/etc/os-release`
2. **Checks for KIWI** with `command -v kiwi-ng`
3. **Installs KIWI** using the appropriate package manager:
   - **Debian/Ubuntu/Proxmox**: `apt-get install python3-kiwi`
   - **OpenSUSE/SLES**: `zypper install python3-kiwi`
   - **RHEL/CentOS/Fedora**: `dnf/yum install python3-kiwi`
4. **Falls back to pip** if package manager installation fails

## Manual Installation

If automatic installation fails, install KIWI manually on your Proxmox host:

### Method 1: APT (Recommended for Proxmox)

```bash
# SSH to Proxmox
ssh root@proxmox

# Update package list
apt-get update

# Install python3-kiwi
apt-get install -y python3-kiwi

# Verify installation
kiwi-ng --version
```

### Method 2: PIP (Alternative)

```bash
# SSH to Proxmox
ssh root@proxmox

# Install pip if not present
apt-get install -y python3-pip

# Install KIWI via pip
pip3 install kiwi

# Verify installation
kiwi-ng --version
```

### Method 3: From Source (Advanced)

```bash
# SSH to Proxmox
ssh root@proxmox

# Install dependencies
apt-get install -y git python3-pip python3-venv

# Clone KIWI repository
git clone https://github.com/OSInside/kiwi.git
cd kiwi

# Install
pip3 install .

# Verify
kiwi-ng --version
```

## Required Dependencies

KIWI requires these packages (automatically installed with `python3-kiwi`):

- `python3` (3.6+)
- `qemu-utils` (for qcow2 image creation)
- `genisoimage` or `xorriso` (for ISO creation)
- `libvirt-daemon-system` (optional, for VM testing)

If you get errors about missing tools, install them:

```bash
apt-get install -y qemu-utils genisoimage xorriso
```

## Verifying Installation

After installation, verify KIWI is working:

```bash
# Check version
kiwi-ng --version

# Should output something like:
# KIWI (next generation) version 9.x.x
```

## Troubleshooting

### Issue: "python3-kiwi not found"

On older Debian/Proxmox versions, the package might not be in the default repositories.

**Solution:** Use pip installation
```bash
apt-get install -y python3-pip
pip3 install kiwi
```

### Issue: "qemu-img not found"

KIWI needs qemu-utils to create qcow2 images.

**Solution:**
```bash
apt-get install -y qemu-utils
```

### Issue: Permission denied

KIWI must run as root.

**Solution:**
```bash
# The build script checks this, but if running manually:
sudo kiwi-ng --version
```

### Issue: Build fails with "No space left on device"

KIWI builds can be large (several GB).

**Solution:**
- Free up space on Proxmox
- Or change `KIWI_BUILD_DIR` to a location with more space:
  ```bash
  # In .env
  export KIWI_BUILD_DIR="/mnt/storage/kiwi-build"
  ```

### Issue: "Module not found" errors

Some Python dependencies might be missing.

**Solution:**
```bash
# Install Python development headers
apt-get install -y python3-dev

# Reinstall KIWI
pip3 install --upgrade kiwi
```

## Proxmox Version Compatibility

The script has been tested on:

- ✅ Proxmox VE 8.x (Debian 12 Bookworm)
- ✅ Proxmox VE 7.x (Debian 11 Bullseye)
- ✅ Proxmox VE 6.x (Debian 10 Buster)

Older versions should work but may require manual KIWI installation via pip.

## Storage Recommendations

KIWI builds require temporary space:

### Minimum Requirements
- **Build process**: ~5-10 GB temporary space
- **Final image**: ~500 MB - 2 GB (depending on packages)

### Recommended Setup

```bash
# Use local-lvm or local storage for build
export KIWI_BUILD_DIR="/var/lib/vz/kiwi-build"

# Store final image on appropriate storage
export OPENSUSE_IMAGE_PATH="/var/lib/vz/template/iso/opensuse-leap-custom.qcow2"
```

For faster builds, use local SSD/NVMe storage for `KIWI_BUILD_DIR`.

## Build Process Overview

When `make build-image` runs on Proxmox:

1. **Install KIWI** (if not present)
   - Detects Debian/Proxmox
   - Runs `apt-get install python3-kiwi`

2. **Create build directory**
   - Default: `/root/kiwi/build`
   - Configurable via `KIWI_BUILD_DIR`

3. **Run KIWI build**
   - Downloads OpenSUSE packages
   - Installs base system
   - Runs configuration scripts
   - Creates qcow2 image

4. **Copy to template directory**
   - Moves image to `OPENSUSE_IMAGE_PATH`
   - Default: `/var/lib/vz/template/iso/`

5. **Cleanup**
   - Build artifacts remain in build directory
   - Can be safely deleted after successful build

## Network Requirements

KIWI downloads packages during build, requiring:

- **Internet access** from Proxmox host
- **HTTP/HTTPS** access to OpenSUSE repositories
- **Bandwidth**: ~500 MB - 2 GB download (depending on packages)

If Proxmox is behind a proxy, configure it:

```bash
export http_proxy="http://proxy:port"
export https_proxy="http://proxy:port"
```

## Complete Example

```bash
# 1. SSH to Proxmox (optional - make does this automatically)
ssh root@proxmox

# 2. From your local machine, run:
make upload-kiwi      # Uploads KIWI files to Proxmox
make build-image      # Runs build on Proxmox

# The script will:
# - Detect Proxmox/Debian
# - Install python3-kiwi via apt-get
# - Build the OpenSUSE image
# - Save to /var/lib/vz/template/iso/opensuse-leap-custom.qcow2
```

## Manual Build Process

If you prefer to build manually:

```bash
# 1. SSH to Proxmox
ssh root@proxmox

# 2. Ensure KIWI is installed
apt-get install -y python3-kiwi

# 3. Navigate to build directory
cd /root/kiwi

# 4. Run build
./build-image.sh

# Or with custom path:
IMAGE_PATH="/custom/path/image.qcow2" ./build-image.sh
```

## Summary

- ✅ **Proxmox uses Debian** → Script uses `apt-get`
- ✅ **Automatic detection** → No manual configuration needed
- ✅ **Fallback to pip** → Works even if package unavailable
- ✅ **Clear error messages** → Easy troubleshooting
- ✅ **Multiple installation methods** → Flexible for different setups

The build script now properly supports Proxmox (Debian-based) systems!
