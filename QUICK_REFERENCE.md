# Quick Reference Guide - Ceph Cluster Deployment

## One-Time Setup

### Build Image (15-40 min)
```bash
scp -r kiwi/ root@proxmox:/root/
ssh root@proxmox 'cd /root/kiwi && ./build-image.sh'
```

### Configure
```bash
# Edit configuration
vim vars/vm_config.yml

# Key settings:
# - github_username: "your-github-username"
# - storage_pool: "nvme-pool"
# - Network bridges: vmbr0, vmbr1
```

### Deploy (2-5 min)
```bash
ansible-playbook -i inventory.ini deploy-vms.yml
```

### Configure VMs (5-10 min)
```bash
vim inventory-vms.ini  # Update with VM IPs
ansible-playbook -i inventory-vms.ini configure-vms.yml
```

## Common Commands

### GitHub SSH Keys

```bash
# Import keys for root
/usr/local/bin/import-github-keys.sh github-username root

# Import keys for another user
/usr/local/bin/import-github-keys.sh github-username admin
```

### Network Discovery

```bash
# View LLDP neighbors
lldpcli show neighbors
lldpcli show neighbors details

# Browse Avahi services
avahi-browse -a
avahi-browse -a -t  # Terminate after dumping

# Resolve hostname
avahi-resolve -n hostname.local
```

### System Updates

```bash
# Update all packages
zypper refresh && zypper update

# Update specific package
zypper update package-name

# Search for package
zypper search package-name
```

### Service Management

```bash
# Check services
systemctl status avahi-daemon
systemctl status lldpd
systemctl status qemu-guest-agent

# Restart services
systemctl restart avahi-daemon
systemctl restart lldpd

# View logs
journalctl -u avahi-daemon
journalctl -u lldpd
```

### Data Disk Management

```bash
# List all disks
lsblk

# Check if disks are unformatted
blkid /dev/sdb /dev/sdc /dev/sdd /dev/sde

# Verify disk sizes
lsblk -d -o NAME,SIZE /dev/sd{b,c,d,e}

# Wipe disk if needed (CAREFUL!)
wipefs -a /dev/sdb
```

### Network Configuration

```bash
# Show interfaces
ip addr
nmcli device status

# Configure static IP
nmcli con mod "System eth0" ipv4.addresses "192.168.1.10/24"
nmcli con mod "System eth0" ipv4.gateway "192.168.1.1"
nmcli con mod "System eth0" ipv4.dns "8.8.8.8"
nmcli con mod "System eth0" ipv4.method manual
nmcli con up "System eth0"

# Show routing table
ip route
```

## Ceph Commands

### Verify Disks for Ceph

```bash
# Check all data disks
for disk in sdb sdc sdd sde; do
  echo "=== /dev/$disk ==="
  lsblk -o NAME,SIZE,TYPE,FSTYPE /dev/$disk
  blkid /dev/$disk 2>&1 || echo "Unformatted (Ready for Ceph)"
done
```

### Deploy Ceph OSDs (Example with cephadm)

```bash
# Add OSDs
ceph orch daemon add osd ceph-node1:/dev/sdb
ceph orch daemon add osd ceph-node1:/dev/sdc
ceph orch daemon add osd ceph-node1:/dev/sdd
ceph orch daemon add osd ceph-node1:/dev/sde

# Check OSD status
ceph osd tree
ceph osd df

# Check cluster health
ceph -s
```

## Proxmox Commands

### VM Management

```bash
# List VMs
qm list

# Get VM config
qm config 200

# Start/stop VMs
qm start 200
qm stop 200
qm shutdown 200

# Console access
qm terminal 200

# Clone VM
qm clone 200 204 --name ceph-node5
```

### Storage

```bash
# List storage
pvesm status

# Check specific storage
pvesm list nvme-pool
```

## Ansible Commands

### Deployment

```bash
# Deploy VMs
ansible-playbook -i inventory.ini deploy-vms.yml

# Configure VMs
ansible-playbook -i inventory-vms.ini configure-vms.yml

# Remove VMs (CAREFUL!)
ansible-playbook -i inventory.ini remove-vms.yml -e "confirm_deletion=true"

# Verbose output
ansible-playbook -i inventory.ini deploy-vms.yml -vvv
```

### Ad-hoc Commands

```bash
# Ping all VMs
ansible -i inventory-vms.ini ceph_nodes -m ping

# Run command on all VMs
ansible -i inventory-vms.ini ceph_nodes -a "uptime"

# Update all VMs
ansible -i inventory-vms.ini ceph_nodes -m command -a "zypper refresh && zypper -n update"

# Check disk usage
ansible -i inventory-vms.ini ceph_nodes -a "df -h"
```

## Troubleshooting

### Can't SSH to VM

```bash
# From Proxmox console
qm terminal 200

# Check SSH service
systemctl status sshd
systemctl restart sshd

# Check network
ip addr
ping 8.8.8.8
```

### GitHub Key Import Fails

```bash
# Test network
curl -I https://github.com

# Check your keys exist on GitHub
curl https://github.com/your-username.keys

# Try manual import
/usr/local/bin/import-github-keys.sh your-username root
```

### LLDP Not Finding Neighbors

```bash
# Check LLDP is running
systemctl status lldpd

# Restart LLDP
systemctl restart lldpd

# Wait 30 seconds, then check
sleep 30 && lldpcli show neighbors

# Check LLDP configuration
cat /etc/sysconfig/lldpd
```

### Avahi Not Working

```bash
# Check avahi status
systemctl status avahi-daemon

# Check avahi config
cat /etc/avahi/avahi-daemon.conf

# Restart avahi
systemctl restart avahi-daemon

# Test resolution
avahi-resolve-host-name localhost.local
```

### Update Fails

```bash
# Check repositories
zypper lr

# Refresh repos
zypper refresh

# Test network
ping download.opensuse.org

# Try with verbose output
zypper -v update
```

## Performance Monitoring

```bash
# CPU/Memory
htop
top

# Disk I/O
iotop
iostat -x 1

# Network
iftop
nethogs

# System stats
vmstat 1
mpstat 1
```

## File Locations

```
/var/lib/vz/template/iso/opensuse-leap-custom.qcow2  # Base image
/etc/pve/qemu-server/200.conf                         # VM config
/usr/local/bin/import-github-keys.sh                  # SSH key import script
/etc/avahi/avahi-daemon.conf                          # Avahi config
/etc/sysconfig/lldpd                                  # LLDP config
```

## Quick Checks

### System Health

```bash
# One-liner system check
echo "=== System ===" && \
uptime && \
echo "=== Disk ===" && \
df -h / && \
echo "=== Memory ===" && \
free -h && \
echo "=== Services ===" && \
systemctl is-active sshd avahi-daemon lldpd qemu-guest-agent
```

### Network Health

```bash
# One-liner network check
echo "=== Interfaces ===" && \
ip -br addr && \
echo "=== Routes ===" && \
ip route && \
echo "=== LLDP Neighbors ===" && \
lldpcli show neighbors
```

### Storage Health

```bash
# Check all disks
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT && \
echo "=== Data Disks ===" && \
for d in sdb sdc sdd sde; do 
  echo -n "/dev/$d: "
  blkid /dev/$d 2>&1 || echo "Unformatted (Ready)"
done
```

## Configuration Files

### vm_config.yml Structure
```yaml
github_username: "username"
storage_pool: "nvme-pool"
data_disk_size: "1000G"
private_bridge: "vmbr1"
public_bridge: "vmbr0"
vm_default_memory: 16384
vm_default_cores: 4
vms:
  - name: "ceph-node1"
    vmid: 200
    memory: 16384
    cores: 4
    ip: "192.168.1.10"
```

### inventory-vms.ini Structure
```ini
[ceph_nodes]
ceph-node1 ansible_host=192.168.1.10
ceph-node2 ansible_host=192.168.1.11
ceph-node3 ansible_host=192.168.1.12
ceph-node4 ansible_host=192.168.1.13

[ceph_nodes:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3
```

## Time Estimates

| Task | Time |
|------|------|
| Build image | 15-40 min |
| Deploy 4 VMs | 2-5 min |
| Configure VMs | 5-10 min |
| Ceph deployment | 15-30 min |

## Useful Aliases

Add to `~/.bashrc`:

```bash
# VM management
alias vmlist='qm list'
alias vmstart='qm start'
alias vmstop='qm stop'
alias vmconfig='qm config'

# LLDP
alias neighbors='lldpcli show neighbors'

# Updates
alias update='zypper refresh && zypper update'

# Disk check
alias checkdisks='lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT'
```
