# OpenSUSE VM Deployment for Ceph Cluster

Fast, automated deployment of OpenSUSE Leap VMs optimized for Ceph storage clusters using Ansible and KIWI.

## Features

- ✅ Deploy 4 OpenSUSE VMs in 2-5 minutes
- ✅ Pre-built KIWI images with automatic updates
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

### Step 1: Build the OpenSUSE Image (One-Time, 15-40 min)

```bash
# Copy kiwi directory to Proxmox host
scp -r kiwi/ root@proxmox:/root/

# Build the image
ssh root@proxmox
cd /root/kiwi
chmod +x build-image.sh
./build-image.sh
```

The build process will:
- Install KIWI if needed
- Build minimal OpenSUSE Leap 15.6 image
- **Run zypper update to install all latest packages**
- Install and configure avahi + lldpd
- Copy image to `/var/lib/vz/template/iso/opensuse-leap-custom.qcow2`

### Step 2: Configure Deployment (2 minutes)

Edit `vars/vm_config.yml`:

```yaml
# Proxmox connection
proxmox_api_user: "root@pam"
proxmox_api_password: "your_password"
proxmox_api_host: "proxmox.example.com"
proxmox_node: "pve"

# GitHub SSH key import (optional but recommended)
github_username: "your-github-username"  # Leave empty to skip

# Storage - single NVMe pool for all disks
storage_pool: "nvme-pool"  # Change to your NVMe storage name
data_disk_size: "1000G"    # Size per data disk (4 disks total)

# Network bridges
private_bridge: "vmbr1"
public_bridge: "vmbr0"

# VM settings
vm_default_memory: 16384  # 16GB RAM
vm_default_cores: 4
```

Update `inventory.ini` with your Proxmox host:

```ini
[proxmox_host]
your-proxmox-host.com ansible_user=root
```

### Step 3: Deploy VMs (2-5 minutes)

```bash
ansible-playbook -i inventory.ini deploy-vms.yml
```

### Step 4: Configure VMs (5-10 minutes)

After deployment, configure the VMs:

```bash
# Update inventory-vms.ini with actual VM IPs
vim inventory-vms.ini

# Run post-deployment configuration
ansible-playbook -i inventory-vms.ini configure-vms.yml
```

This will:
- Import your GitHub SSH keys
- Run `zypper update` to get latest packages
- Verify avahi-daemon is running
- Verify lldpd is running
- Check data disks are ready for Ceph

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
