#!/bin/bash
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Setup baseproduct link
#--------------------------------------
suseSetupProduct

#======================================
# Force IPv4 for package operations
#--------------------------------------
echo "Configuring IPv4 preference for faster downloads..."
export ZYPP_MEDIA_CURL_IPRESOLVE=4

#======================================
# System Update
#--------------------------------------
echo "Updating system packages to latest versions..."
zypper --non-interactive refresh
zypper --non-interactive update -y

#======================================
# Activate services
#--------------------------------------
systemctl enable sshd
systemctl enable qemu-guest-agent
systemctl enable NetworkManager
systemctl enable cloud-init
systemctl enable cloud-init-local
systemctl enable cloud-config
systemctl enable cloud-final
systemctl enable avahi-daemon
systemctl enable lldpd

# Disable unnecessary services
systemctl disable firewalld
systemctl mask firewalld

#======================================
# Setup default target
#--------------------------------------
baseSetRunlevel multi-user.target

#======================================
# Set root password
#--------------------------------------
# Set default root password (can be changed via cloud-init or manually)
echo "root:opensuse" | chpasswd
echo "Default root password set to: opensuse"

#======================================
# SSH Configuration
#--------------------------------------
# Enable SSH root login
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Enable password authentication (can be disabled after key-based auth is set up)
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Enable public key authentication
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

#======================================
# GitHub SSH Key Import Script
#--------------------------------------
# Create script to pull SSH keys from GitHub
cat > /usr/local/bin/import-github-keys.sh <<'EOFSCRIPT'
#!/bin/bash
# Import SSH keys from GitHub for specified users
# Usage: import-github-keys.sh <github_username> [target_user]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <github_username> [target_user]"
    echo "Example: $0 octocat root"
    exit 1
fi

GITHUB_USER="$1"
TARGET_USER="${2:-root}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

if [ -z "$TARGET_HOME" ]; then
    echo "Error: User $TARGET_USER not found"
    exit 1
fi

SSH_DIR="$TARGET_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

echo "Importing SSH keys for GitHub user: $GITHUB_USER"
echo "Target user: $TARGET_USER ($TARGET_HOME)"

# Create .ssh directory if it doesn't exist
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Fetch keys from GitHub
GITHUB_KEYS_URL="https://github.com/$GITHUB_USER.keys"
echo "Fetching keys from: $GITHUB_KEYS_URL"

# Force IPv4 to avoid IPv6 connection issues
if curl -4 -f -s "$GITHUB_KEYS_URL" > /tmp/github_keys_temp; then
    if [ -s /tmp/github_keys_temp ]; then
        # Backup existing authorized_keys if it exists
        if [ -f "$AUTHORIZED_KEYS" ]; then
            cp "$AUTHORIZED_KEYS" "$AUTHORIZED_KEYS.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Add GitHub keys to authorized_keys
        cat /tmp/github_keys_temp >> "$AUTHORIZED_KEYS"
        
        # Set proper permissions
        chmod 600 "$AUTHORIZED_KEYS"
        chown -R "$TARGET_USER:$(id -gn $TARGET_USER)" "$SSH_DIR"
        
        echo "Successfully imported $(wc -l < /tmp/github_keys_temp) SSH keys"
        rm /tmp/github_keys_temp
    else
        echo "Error: No keys found for GitHub user $GITHUB_USER"
        rm /tmp/github_keys_temp
        exit 1
    fi
else
    echo "Error: Failed to fetch keys from GitHub for user $GITHUB_USER"
    exit 1
fi
EOFSCRIPT

chmod +x /usr/local/bin/import-github-keys.sh

# Create systemd service for GitHub key import on first boot
cat > /etc/systemd/system/import-github-keys.service <<'EOFSERVICE'
[Unit]
Description=Import SSH keys from GitHub
After=network-online.target
Wants=network-online.target
Before=sshd.service
ConditionPathExists=/etc/github-ssh-user

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/local/bin/import-github-keys.sh $(cat /etc/github-ssh-user) root'
ExecStartPost=/bin/rm -f /etc/github-ssh-user
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Note: Create /etc/github-ssh-user with GitHub username to enable auto-import on first boot

#======================================
# Network Configuration
#--------------------------------------
# Use traditional network interface names (eth0, eth1)
# Already set in kernel command line: net.ifnames=0 biosdevname=0

# Configure NetworkManager to use DHCP by default
cat > /etc/NetworkManager/conf.d/dhcp.conf <<EOF
[main]
dhcp=dhclient
EOF

#======================================
# LLDP Configuration
#--------------------------------------
# Configure LLDP daemon for network discovery
cat > /etc/lldpd.d/README.conf <<EOF
# LLDP Configuration for Network Discovery
# System will advertise itself on the network via LLDP
# Use 'lldpcli show neighbors' to see discovered devices
EOF

# Configure lldpd to listen on all interfaces
cat > /etc/sysconfig/lldpd <<EOF
# LLDP daemon configuration
LLDPD_OPTIONS="-c -e -f -s -r"
# -c: Enable CDP support
# -e: Enable EDP support  
# -f: Enable FDP support
# -s: Enable SONMP support
# -r: Receive-only mode disabled (both transmit and receive)
EOF

#======================================
# Avahi Configuration
#--------------------------------------
# Configure Avahi for mDNS/DNS-SD (service discovery)
cat > /etc/avahi/avahi-daemon.conf <<EOF
[server]
host-name-from-machine-id=yes
use-ipv4=yes
use-ipv6=yes
allow-interfaces=eth0,eth1
deny-interfaces=lo
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes

[reflector]
enable-reflector=no

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=768
rlimit-stack=4194304
rlimit-nproc=3
EOF

#======================================
# Cloud-init Configuration
#--------------------------------------
cat > /etc/cloud/cloud.cfg.d/99_custom.cfg <<EOF
# Custom cloud-init configuration
datasource_list: [ NoCloud, ConfigDrive, None ]
disable_root: false
ssh_pwauth: true
preserve_hostname: false

# Default user configuration
system_info:
  default_user:
    name: admin
    groups: [wheel, users]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: false

# SSH import configuration
# To import SSH keys from GitHub, add to user-data:
# ssh_import_id: [gh:username]
# Or use the import-github-keys.sh script

# Network configuration
network:
  config: disabled

# Package management
package_upgrade: false
package_reboot_if_required: false

# Module configuration
cloud_init_modules:
  - migrator
  - seed_random
  - bootcmd
  - write-files
  - growpart
  - resizefs
  - disk_setup
  - mounts
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - ca-certs
  - rsyslog
  - users-groups
  - ssh

cloud_config_modules:
  - runcmd
  - scripts-user

cloud_final_modules:
  - scripts-per-once
  - scripts-per-boot
  - scripts-per-instance
  - scripts-user
  - ssh-authkey-fingerprints
  - keys-to-console
  - final-message

# NOTE: Data disks (sdb, sdc, sdd, sde) are intentionally left unformatted
# These disks are intended for Ceph OSD usage and should not be automatically
# mounted or formatted during deployment
EOF

#======================================
# Locale Configuration
#--------------------------------------
# Ensure UK locale is generated (en_GB is the default in config.xml)
# This generates additional locales that might be useful
echo "Generating locales..."
localectl set-locale LANG=en_GB.UTF-8 || true

#======================================
# Sudoers Configuration
#--------------------------------------
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

#======================================
# Performance Tuning
#--------------------------------------
# Disable unnecessary kernel modules
cat > /etc/modprobe.d/blacklist-custom.conf <<EOF
# Blacklist unnecessary modules
blacklist pcspkr
blacklist floppy
EOF

# Optimize VM performance
cat > /etc/sysctl.d/99-vm-performance.conf <<EOF
# VM performance tuning
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Network performance
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
EOF

#======================================
# Cleanup
#--------------------------------------
# Remove unnecessary files
rm -rf /var/cache/zypp/*
rm -rf /var/log/*
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear machine-id for cloud-init
truncate -s 0 /etc/machine-id

#======================================
# GRUB Configuration
#--------------------------------------
# Update GRUB configuration
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200 net.ifnames=0 biosdevname=0 quiet"/' /etc/default/grub

echo "Configuration complete!"
exit 0
