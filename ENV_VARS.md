# Environment Variable Configuration Guide

## Overview

All configuration options can be set using environment variables, making it easy to:
- Deploy in CI/CD pipelines
- Use different configurations without editing files
- Script multiple deployments
- Keep sensitive credentials separate from config files

## Quick Start with Environment Variables

### Method 1: Using .env File (Recommended)

```bash
# 1. Copy the example file
cp .env.example .env

# 2. Edit with your settings
vim .env

# 3. Deploy
./deploy-with-env.sh
```

### Method 2: Export Variables Manually

```bash
# Set your variables
export PROXMOX_API_HOST="proxmox.example.com"
export PROXMOX_API_PASSWORD="your_password"
export STORAGE_POOL="nvme-pool"
export VM_DEFAULT_MEMORY="32768"  # 32GB per VM
export VM_DEFAULT_CORES="8"       # 8 cores per VM

# Generate config and deploy
./generate-config.sh
./generate-inventory.sh
ansible-playbook -i inventory.ini deploy-vms.yml
```

### Method 3: One-Line Deployment

```bash
PROXMOX_API_HOST=pve.local \
PROXMOX_API_PASSWORD=secret \
STORAGE_POOL=nvme-pool \
VM_DEFAULT_MEMORY=16384 \
VM_DEFAULT_CORES=4 \
./deploy-with-env.sh
```

## All Environment Variables

### Proxmox Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PROXMOX_API_USER` | `root@pam` | Proxmox API user |
| `PROXMOX_API_PASSWORD` | `your_password_here` | Proxmox API password |
| `PROXMOX_API_HOST` | `proxmox.example.com` | Proxmox hostname/IP |
| `PROXMOX_NODE` | `pve` | Proxmox node name |
| `PROXMOX_SSH_USER` | `root` | SSH user for Proxmox |
| `PROXMOX_SSH_KEY` | `~/.ssh/id_rsa` | SSH key for Proxmox |

### Image Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENSUSE_IMAGE_PATH` | `/var/lib/vz/template/iso/opensuse-leap-custom.qcow2` | Path to image on Proxmox |

### GitHub SSH Keys

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_USERNAME` | `""` | GitHub username for SSH key import (empty = skip) |

### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `STORAGE_POOL` | `nvme-pool` | Proxmox storage pool name |
| `DATA_DISK_SIZE` | `1000G` | Size of each data disk (4 per VM) |

### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PRIVATE_BRIDGE` | `vmbr1` | Private/cluster network bridge |
| `PUBLIC_BRIDGE` | `vmbr0` | Public/client network bridge |

### VM Default Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VM_DEFAULT_MEMORY` | `16384` | Default RAM in MB (16GB) |
| `VM_DEFAULT_CORES` | `4` | Default CPU cores |
| `VM_DEFAULT_SOCKETS` | `1` | Default CPU sockets |
| `VM_CPU_TYPE` | `host` | CPU type for VMs |
| `AUTO_START` | `true` | Auto-start VMs after creation |
| `VM_ROOT_PASSWORD` | `opensuse` | Root password for VMs |
| `NUM_VMS` | `4` | Number of VMs to deploy (1-4) |

### Individual VM Configuration

Each VM can be configured individually. Replace `N` with VM number (1-4):

| Variable | Default | Description |
|----------|---------|-------------|
| `VMN_NAME` | `ceph-nodeN` | VM hostname |
| `VMN_VMID` | `199+N` | Proxmox VM ID |
| `VMN_MEMORY` | `$VM_DEFAULT_MEMORY` | RAM in MB |
| `VMN_CORES` | `$VM_DEFAULT_CORES` | CPU cores |
| `VMN_SOCKETS` | `$VM_DEFAULT_SOCKETS` | CPU sockets |
| `VMN_ONBOOT` | `1` | Start on Proxmox boot |
| `VMN_IP` | `192.168.1.9+N` | IP address |

## Common Configuration Examples

### Example 1: Small Development Cluster

```bash
# .env
export VM_DEFAULT_MEMORY="8192"   # 8GB
export VM_DEFAULT_CORES="4"
export DATA_DISK_SIZE="500G"
export NUM_VMS="3"
```

### Example 2: Production Cluster

```bash
# .env
export VM_DEFAULT_MEMORY="32768"  # 32GB
export VM_DEFAULT_CORES="8"
export DATA_DISK_SIZE="2000G"     # 2TB per disk
export NUM_VMS="4"
export STORAGE_POOL="nvme-pool"
```

### Example 3: High-Performance Cluster

```bash
# .env
export VM_DEFAULT_MEMORY="65536"  # 64GB
export VM_DEFAULT_CORES="16"
export DATA_DISK_SIZE="4000G"     # 4TB per disk
export VM_CPU_TYPE="host"
```

### Example 4: Mixed VM Sizes

```bash
# .env
# Defaults
export VM_DEFAULT_MEMORY="16384"
export VM_DEFAULT_CORES="4"

# Override specific VMs
export VM1_MEMORY="32768"   # VM1: 32GB
export VM1_CORES="8"        # VM1: 8 cores
export VM2_MEMORY="16384"   # VM2: 16GB (default)
export VM3_MEMORY="65536"   # VM3: 64GB
export VM3_CORES="16"       # VM3: 16 cores
export VM4_MEMORY="16384"   # VM4: 16GB (default)
```

### Example 5: Different Storage Pools

```bash
# .env
export STORAGE_POOL="local-lvm"
# All VMs use same pool by default
```

### Example 6: Custom Network Bridges

```bash
# .env
export PRIVATE_BRIDGE="vmbr2"  # Dedicated cluster network
export PUBLIC_BRIDGE="vmbr0"   # Public network
```

## Memory Configuration Examples

```bash
# 8GB per VM
export VM_DEFAULT_MEMORY="8192"

# 16GB per VM (default)
export VM_DEFAULT_MEMORY="16384"

# 32GB per VM
export VM_DEFAULT_MEMORY="32768"

# 64GB per VM
export VM_DEFAULT_MEMORY="65536"

# 128GB per VM
export VM_DEFAULT_MEMORY="131072"
```

## CPU Configuration Examples

```bash
# 4 cores per VM (default)
export VM_DEFAULT_CORES="4"

# 8 cores per VM
export VM_DEFAULT_CORES="8"

# 16 cores per VM
export VM_DEFAULT_CORES="16"

# 24 cores per VM
export VM_DEFAULT_CORES="24"

# With multiple sockets (2 sockets x 8 cores = 16 total)
export VM_DEFAULT_CORES="8"
export VM_DEFAULT_SOCKETS="2"
```

## Deployment Workflows

### Workflow 1: Complete Automated Deployment

```bash
# 1. Create .env from template
cp .env.example .env

# 2. Edit .env with your settings
vim .env

# 3. Run complete deployment
./deploy-with-env.sh
```

### Workflow 2: Step-by-Step Deployment

```bash
# 1. Set environment variables
source .env

# 2. Generate configurations
./generate-config.sh
./generate-inventory.sh

# 3. Deploy VMs
ansible-playbook -i inventory.ini deploy-vms.yml

# 4. Configure VMs
ansible-playbook -i inventory-vms.ini configure-vms.yml
```

### Workflow 3: CI/CD Pipeline

```yaml
# Example GitLab CI
deploy_cluster:
  script:
    - export PROXMOX_API_HOST=$CI_PROXMOX_HOST
    - export PROXMOX_API_PASSWORD=$CI_PROXMOX_PASSWORD
    - export STORAGE_POOL=$CI_STORAGE_POOL
    - ./deploy-with-env.sh
  only:
    - main
```

### Workflow 4: Multiple Environments

```bash
# Development
cp .env.example .env.dev
vim .env.dev  # Set dev settings
source .env.dev
./generate-config.sh
ansible-playbook -i inventory.ini deploy-vms.yml

# Production
cp .env.example .env.prod
vim .env.prod  # Set prod settings
source .env.prod
./generate-config.sh
ansible-playbook -i inventory.ini deploy-vms.yml
```

## Scripts Reference

### generate-config.sh

Generates `vars/vm_config.yml` from environment variables.

```bash
./generate-config.sh
```

### generate-inventory.sh

Generates `inventory.ini` and `inventory-vms.ini` from environment variables.

```bash
./generate-inventory.sh
```

### deploy-with-env.sh

Complete deployment using environment variables:
1. Loads .env file
2. Generates configurations
3. Validates prerequisites
4. Deploys VMs
5. Configures VMs

```bash
./deploy-with-env.sh
```

## Tips and Best Practices

### Security

1. **Never commit .env files to version control**
   ```bash
   echo ".env" >> .gitignore
   ```

2. **Use strong passwords**
   ```bash
   export PROXMOX_API_PASSWORD="$(openssl rand -base64 32)"
   ```

3. **Use SSH keys instead of passwords**
   ```bash
   # After deployment, switch to SSH keys
   vim inventory-vms.ini
   # Comment out ansible_ssh_pass
   # Uncomment ansible_ssh_private_key_file
   ```

### Memory Planning

Calculate total memory usage:
```bash
TOTAL_MEMORY=$((VM_DEFAULT_MEMORY * NUM_VMS))
echo "Total RAM needed: ${TOTAL_MEMORY}MB ($(($TOTAL_MEMORY / 1024))GB)"
```

### Storage Planning

Calculate total storage usage:
```bash
OS_TOTAL=$((50 * NUM_VMS))  # 50GB OS per VM
DATA_SIZE_GB=$(echo $DATA_DISK_SIZE | sed 's/G//')
DATA_TOTAL=$((DATA_SIZE_GB * 4 * NUM_VMS))  # 4 data disks per VM
TOTAL_STORAGE=$((OS_TOTAL + DATA_TOTAL))
echo "Total storage needed: ${TOTAL_STORAGE}GB"
```

### Validation

Validate your configuration before deployment:
```bash
source .env
./generate-config.sh
# Review vars/vm_config.yml
cat vars/vm_config.yml
```

### Testing

Test with smaller values first:
```bash
export NUM_VMS="1"
export VM_DEFAULT_MEMORY="8192"
export DATA_DISK_SIZE="100G"
./deploy-with-env.sh
```

## Troubleshooting

### Configuration Not Applied

```bash
# Make sure to regenerate configs after changing .env
source .env
./generate-config.sh
./generate-inventory.sh
```

### Memory Errors

```bash
# Check available memory on Proxmox
ssh root@$PROXMOX_API_HOST "free -h"

# Reduce VM memory
export VM_DEFAULT_MEMORY="8192"
./generate-config.sh
```

### Storage Errors

```bash
# Check available storage
ssh root@$PROXMOX_API_HOST "pvesm status"

# Use different storage pool
export STORAGE_POOL="local-lvm"
./generate-config.sh
```

## Environment Variable Priority

1. Command-line exports (highest priority)
2. .env file
3. Default values in scripts (lowest priority)

Example:
```bash
# This overrides .env file
VM_DEFAULT_MEMORY=32768 ./deploy-with-env.sh
```

## Verification

After deployment, verify configuration:
```bash
# Check VM memory
ansible -i inventory-vms.ini ceph_nodes -a "free -h"

# Check VM cores
ansible -i inventory-vms.ini ceph_nodes -a "nproc"

# Check disks
ansible -i inventory-vms.ini ceph_nodes -a "lsblk"
```
