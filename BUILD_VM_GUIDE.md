## Build VM Guide - Dedicated KIWI Image Builder

This guide explains how to use a dedicated OpenSUSE VM running on Proxmox for building KIWI images. This is the **RECOMMENDED** approach since KIWI works best on OpenSUSE.

## Why Use a Build VM?

### Problems with Building on Proxmox Directly
- Proxmox is Debian-based, KIWI is designed for OpenSUSE
- Package availability and compatibility issues
- Python dependencies conflicts
- Harder to troubleshoot build failures

### Benefits of Build VM Approach
✅ **Native environment** - OpenSUSE with full KIWI support
✅ **Clean separation** - Build doesn't affect Proxmox host
✅ **Reproducible** - Consistent build environment
✅ **Reusable** - Keep VM running, build multiple times
✅ **Easy troubleshooting** - Full OpenSUSE tooling available
✅ **Automated** - One command deploys and builds

## Quick Start

### 1. Deploy the Build VM (One-Time Setup)

```bash
# Initialize configuration
make init
make edit-env  # Configure Proxmox settings

# Deploy build VM (takes ~5 minutes)
make deploy-build-vm
```

This will:
- Download OpenSUSE cloud image
- Create VM on Proxmox (VM ID 100 by default)
- Install KIWI and dependencies
- Auto-detect and save IP address
- Leave VM running and ready

### 2. Build Image on Build VM

```bash
# Build image (takes 15-40 minutes)
make build-image-remote
```

This will:
- Upload KIWI configuration to build VM
- Build image on OpenSUSE build VM
- Transfer completed image to Proxmox
- Place image at configured path
- Clean up build artifacts

### 3. Deploy VMs Using Built Image

```bash
# Verify image
make check-image

# Deploy your VMs
make deploy
```

## Configuration

### Build VM Settings (.env)

```bash
# Build VM configuration
export BUILD_VM_ID="100"                  # VM ID (change if conflict)
export BUILD_VM_NAME="kiwi-builder"       # VM name
export BUILD_VM_MEMORY="4096"             # 4GB RAM (minimum recommended)
export BUILD_VM_CORES="4"                 # CPU cores
export BUILD_VM_DISK_SIZE="50G"           # Disk size
export BUILD_VM_STORAGE="local-lvm"       # Storage pool for VM
export BUILD_VM_BRIDGE="vmbr0"            # Network bridge
export BUILD_VM_IP=""                     # Auto-detected (or set manually)
```

### Resource Requirements

**Minimum:**
- 2 GB RAM
- 2 CPU cores
- 30 GB disk space

**Recommended:**
- 4 GB RAM
- 4 CPU cores
- 50 GB disk space

**For faster builds:**
- 8 GB RAM
- 8 CPU cores
- Place on NVMe/SSD storage

## Complete Workflow

### First Time Setup

```bash
# 1. Configure environment
make init
make edit-env

# 2. Deploy build VM
make deploy-build-vm

# Wait for deployment to complete (~5 minutes)
# Build VM IP is auto-detected and saved

# 3. Build your first image
make build-image-remote

# 4. Verify and deploy
make check-image
make deploy
```

### Subsequent Builds

The build VM stays running, so subsequent builds are faster:

```bash
# Just rebuild - VM is already set up
make build-image-remote
```

## Make Commands

### Build VM Management

| Command | Description |
|---------|-------------|
| `make deploy-build-vm` | Deploy the build VM (one-time setup) |
| `make build-vm-status` | Check build VM status and IP |
| `make ssh-build-vm` | SSH into the build VM |
| `make remove-build-vm` | Remove the build VM |

### Image Building

| Command | Description |
|---------|-------------|
| `make build-image-remote` | Build on build VM (RECOMMENDED) |
| `make build-image` | Build on Proxmox host (legacy method) |
| `make check-image` | Verify image exists on Proxmox |

## Manual Operations

### SSH into Build VM

```bash
# Using make
make ssh-build-vm

# Or directly
ssh root@<BUILD_VM_IP>
```

### Check Build VM Status

```bash
make build-vm-status
```

Output shows:
- VM ID and name
- IP address
- Running status

### Manual Build Process

If you want to build manually:

```bash
# 1. SSH to build VM
make ssh-build-vm

# 2. Navigate to build directory
cd /root/kiwi-builds

# 3. Run build
./build-image.sh

# 4. Transfer to Proxmox (from your local machine)
scp root@<BUILD_VM_IP>:/root/kiwi-builds/output/*.qcow2 \
    root@proxmox:/var/lib/vz/template/iso/
```

## Troubleshooting

### Build VM Won't Deploy

**Problem:** Deployment fails or hangs

**Solutions:**
```bash
# Check if VM ID is available
ssh root@proxmox "qm list | grep 100"

# Use different VM ID if 100 is taken
# In .env:
export BUILD_VM_ID="101"

# Check storage exists
ssh root@proxmox "pvesm list"

# Use different storage if needed
export BUILD_VM_STORAGE="local"
```

### Cannot Detect Build VM IP

**Problem:** IP address auto-detection fails

**Solutions:**
```bash
# Option 1: Check VM console
ssh root@proxmox "qm terminal 100"
# Type 'ip a' to see IP address

# Option 2: Use DHCP lease
ssh root@proxmox "grep kiwi /var/lib/misc/dnsmasq.leases"

# Option 3: Set static IP
# In .env before deploying:
export BUILD_VM_IP="192.168.1.50"
```

### Build Fails on Build VM

**Problem:** KIWI build fails

**Solutions:**
```bash
# SSH to build VM
make ssh-build-vm

# Check logs
cd /root/kiwi-builds
tail -f build/build.log

# Check disk space
df -h

# Check network
ping -c 3 download.opensuse.org

# Retry build manually
./build-image.sh
```

### Image Transfer Fails

**Problem:** Cannot transfer image from build VM to Proxmox

**Solutions:**
```bash
# Check connectivity
ssh root@<BUILD_VM_IP> "ping -c 3 <PROXMOX_HOST>"

# Check SSH keys
ssh root@<BUILD_VM_IP> "ssh root@<PROXMOX_HOST> 'echo connected'"

# Manual transfer
scp root@<BUILD_VM_IP>:/root/kiwi-builds/output/*.qcow2 /tmp/
scp /tmp/*.qcow2 root@proxmox:/var/lib/vz/template/iso/
```

### Build VM Uses Too Much Space

**Problem:** Disk filling up on build VM

**Solutions:**
```bash
# SSH to build VM
make ssh-build-vm

# Clean old builds
cd /root/kiwi-builds
rm -rf build/ output/

# Check space
df -h

# Expand disk if needed (from Proxmox)
ssh root@proxmox "qm resize 100 scsi0 +20G"

# Then on build VM
growpart /dev/sda 1
resize2fs /dev/sda1
```

## Advanced Configuration

### Static IP Address

Set before deploying:

```bash
# In .env
export BUILD_VM_IP="192.168.1.50"
export BUILD_VM_GATEWAY="192.168.1.1"
```

### Custom Storage Location

Use faster storage for builds:

```bash
# In .env
export BUILD_VM_STORAGE="nvme-pool"
```

### Multiple Build VMs

Run multiple build VMs for parallel builds:

```bash
# Build VM 1 (OpenSUSE Leap)
export BUILD_VM_ID="100"
export BUILD_VM_NAME="kiwi-leap"
make deploy-build-vm

# Build VM 2 (OpenSUSE Tumbleweed)
export BUILD_VM_ID="101"
export BUILD_VM_NAME="kiwi-tumbleweed"
make deploy-build-vm
```

### Build VM on Different Network

Use separate network for builds:

```bash
# In .env
export BUILD_VM_BRIDGE="vmbr1"  # Isolated build network
```

## Maintenance

### Update Build VM

```bash
# SSH to build VM
make ssh-build-vm

# Update system
zypper refresh
zypper update -y

# Update KIWI
zypper update python3-kiwi
```

### Backup Build VM

```bash
# Create backup
ssh root@proxmox "vzdump 100 --mode snapshot"

# Restore if needed
ssh root@proxmox "qmrestore /path/to/backup 100"
```

### Stop Build VM (Save Resources)

```bash
# Stop when not building
ssh root@proxmox "qm stop 100"

# Start when needed
ssh root@proxmox "qm start 100"

# Wait for boot
sleep 60

# Continue building
make build-image-remote
```

### Remove Build VM

```bash
# When no longer needed
make remove-build-vm

# Confirm deletion
# VM and all data will be removed
```

## Comparison: Build VM vs Direct Build

| Aspect | Build VM (Recommended) | Direct on Proxmox |
|--------|----------------------|-------------------|
| **OS Compatibility** | ✅ Native OpenSUSE | ⚠️ Debian-based |
| **KIWI Support** | ✅ Full support | ⚠️ Limited |
| **Package Availability** | ✅ Complete | ⚠️ May be missing |
| **Setup Time** | ~5 minutes | ~2 minutes |
| **Build Reliability** | ✅ High | ⚠️ Medium |
| **Troubleshooting** | ✅ Easy | ⚠️ Harder |
| **Resource Usage** | Uses VM resources | Uses host resources |
| **Reusability** | ✅ Keep VM running | Must reinstall |
| **Isolation** | ✅ Separate VM | ❌ Affects host |

## Best Practices

1. **Use Build VM for Production**
   - More reliable and consistent
   - Easier to troubleshoot
   - Better separation of concerns

2. **Keep Build VM Running**
   - Faster subsequent builds
   - No setup time
   - Ready when needed

3. **Allocate Adequate Resources**
   - Minimum 4GB RAM
   - 4+ CPU cores
   - 50GB disk space

4. **Use Fast Storage**
   - NVMe/SSD for BUILD_VM_STORAGE
   - Speeds up builds significantly

5. **Monitor Disk Space**
   - Clean up after builds
   - Expand disk if needed

6. **Regular Updates**
   - Keep KIWI updated
   - Update OpenSUSE packages

## Example: Complete First-Time Workflow

```bash
# 1. Setup
git clone https://github.com/yourorg/vm-deploy.git
cd vm-deploy
make init
vi .env  # Configure your Proxmox settings

# 2. Deploy build VM (one-time, ~5 min)
make deploy-build-vm

# Output:
# ==========================================
# Build VM Deployment Complete!
# ==========================================
# VM Details:
#   VM ID: 100
#   VM Name: kiwi-builder
#   IP Address: 192.168.1.100
# ==========================================

# 3. Build image (~15-40 min)
make build-image-remote

# Output:
# ==========================================
# Building OpenSUSE Image on Build VM
# ==========================================
# ... build progress ...
# Image Build and Transfer Complete!
# ==========================================

# 4. Verify and deploy
make check-image
make deploy

# 5. Future builds (VM already set up)
make build-image-remote  # Much faster!
```

## Summary

**Recommended Workflow:**
1. Deploy build VM once: `make deploy-build-vm`
2. Build images as needed: `make build-image-remote`
3. Keep VM running for faster rebuilds
4. Remove when done: `make remove-build-vm`

**Key Advantages:**
- Native OpenSUSE environment
- Full KIWI support
- Reliable and reproducible
- Easy to troubleshoot
- Reusable for multiple builds

The build VM approach is now the recommended method for all KIWI image building operations!
