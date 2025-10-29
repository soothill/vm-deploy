# Deployment from Linux Machine

<!-- Copyright (c) 2025 Darren Soothill -->
<!-- Email: darren [at] soothill [dot] com -->
<!-- License: MIT -->

This guide is for deploying from your Linux machine (`darren@syslog`) after developing on Mac.

## Prerequisites on Linux Machine

1. **Pull latest changes from Git:**
   ```bash
   cd ~/vm-deploy
   git pull
   ```

2. **Install Ansible and Python libraries:**
   ```bash
   # Install Ansible
   sudo apt update
   sudo apt install ansible

   # Install Python libraries for Proxmox module
   pip3 install --user proxmoxer requests
   ```

3. **Verify installation:**
   ```bash
   ansible --version
   python3 -c "import proxmoxer, requests; print('Libraries installed')"
   ```

## Configuration

Your `.env` file should already be configured with:
- `PROXMOX_API_HOST="proxmox.local"`
- `PROXMOX_SSH_USER="root"`
- `PROXMOX_SSH_KEY="~/.ssh/id_rsa"`

If you regenerate the inventory, run:
```bash
make generate-inventory
```

## Deployment Steps

### 1. Test Connection
```bash
make test-connection
```

**Expected output:**
```
Testing connection to Proxmox host...
proxmox.local | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
Connection successful!
```

### 2. Check Image Exists
```bash
make check-image
```

Should show:
```
✓ Image found at /wdred/iso/template/iso/opensuse-leap-custom.qcow2
```

### 3. Deploy VMs
```bash
make deploy
```

This will:
- Check Python libraries are installed
- Check image exists
- Create 4 VMs with configured resources
- Attach disks and network
- Configure cloud-init

### 4. After VMs Boot

Get the IP addresses from Proxmox GUI or DHCP, then update:
```bash
nano inventory-vms.ini
# Update the IP addresses for each VM
```

### 5. Configure VMs
```bash
make configure
```

This runs post-deployment configuration on the VMs.

## Troubleshooting

### SSH Permission Denied
If you get "Permission denied (publickey,password)":

1. Check SSH key is in Proxmox:
   ```bash
   ssh root@proxmox.local "cat ~/.ssh/authorized_keys"
   ```

2. Check your SSH key exists:
   ```bash
   ls -la ~/.ssh/id_rsa*
   ```

3. Test manual SSH:
   ```bash
   ssh root@proxmox.local
   ```

4. If needed, copy your key:
   ```bash
   ssh-copy-id root@proxmox.local
   ```

### Python Libraries Not Found
```bash
# Install locally
pip3 install --user proxmoxer requests

# Or system-wide
sudo pip3 install proxmoxer requests
```

### Ansible Not in PATH
If `ansible` command not found after pip install:
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# Reload shell
source ~/.bashrc
```

## Quick Reference

| Command | Purpose |
|---------|---------|
| `make test-connection` | Test SSH to Proxmox |
| `make check-image` | Verify image exists |
| `make deploy` | Deploy VMs |
| `make configure` | Configure deployed VMs |
| `make status` | Check deployment status |
| `make remove CONFIRM_DELETE=true` | Remove VMs |

## What's Different from Mac

- **Ansible location**: `/usr/bin/ansible` (apt) vs `~/Library/Python/3.13/bin/ansible` (pip on Mac)
- **Python libraries**: `~/.local/lib/pythonX.X/site-packages` on Linux vs `~/Library/Python/3.13/` on Mac
- **No Homebrew issues**: No need for `--break-system-packages` flag

All the fixes and improvements we made on Mac are now pushed to the repo, so when you `git pull` on Linux, you'll have:
- ✅ Proper SSH key configuration in inventory
- ✅ Fixed IP detection scripts
- ✅ IPv4-only downloads
- ✅ VM/Container ID collision detection
- ✅ All bug fixes from this session
