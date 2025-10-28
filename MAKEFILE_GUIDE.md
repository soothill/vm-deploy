# Makefile Usage Guide

Complete guide to using the Makefile wrapper for Ansible-based VM deployment.

## Overview

The Makefile provides a simplified interface to all Ansible operations, handling:
- Environment variable loading from `.env`
- Ansible playbook execution with proper options
- Error checking and validation
- Common workflows and shortcuts

## Getting Started

### 1. View All Available Commands

```bash
make help
```

This displays all available targets organized by category with descriptions.

### 2. Initialize Your Environment

```bash
# Create .env from template
make init

# Edit configuration
make edit-env
```

### 3. Check Status

```bash
# Show current configuration status
make status

# Show detailed configuration
make info
```

## Common Workflows

### Complete Deployment from Scratch

```bash
# 1. Initialize
make init
make edit-env  # Configure your settings

# 2. Upload and build image (one-time)
make upload-kiwi
make build-image

# 3. Deploy and configure
make deploy-full

# Or step by step:
make test-connection   # Verify Proxmox connection
make deploy           # Deploy VMs
make edit-vm-inventory  # Update with VM IPs
make configure        # Configure VMs
```

### Quick Re-deployment

```bash
# Remove existing VMs and redeploy
make remove CONFIRM_DELETE=true
make deploy-full
```

### Testing and Validation

```bash
# Test connections
make test-connection      # Test Proxmox connection
make test-vm-connection   # Test VM connections

# Syntax checking
make check-syntax

# Dry-run (no changes made)
make dry-run
make deploy CHECK=1
make configure CHECK=1
```

## Command Reference

### Main Operations

#### `make all`
Full deployment workflow: checks image, deploys VMs, and configures them.

```bash
make all
```

#### `make deploy`
Deploy VMs to Proxmox.

```bash
# Basic deployment
make deploy

# With verbose output
make deploy VERBOSE=2

# Dry-run to see what would happen
make deploy CHECK=1

# Show differences
make deploy DIFF=1
```

#### `make configure`
Configure deployed VMs (updates, SSH keys, services).

```bash
make configure

# With options
make configure VERBOSE=2 CHECK=1
```

#### `make deploy-full`
Deploy and configure in one step.

```bash
make deploy-full
```

#### `make remove`
Remove VMs (requires explicit confirmation).

```bash
# Must use CONFIRM_DELETE=true
make remove CONFIRM_DELETE=true

# With verbose output
make remove CONFIRM_DELETE=true VERBOSE=1
```

### Image Management

#### `make build-image`
Build OpenSUSE image on Proxmox host (15-40 minutes).

```bash
make build-image
```

This will:
- SSH to Proxmox host
- Execute KIWI build script
- Install all packages and updates
- Copy image to templates directory

#### `make check-image`
Verify the OpenSUSE image exists on Proxmox.

```bash
make check-image
```

#### `make upload-kiwi`
Upload KIWI build directory to Proxmox.

```bash
make upload-kiwi
```

### VM Operations

#### `make list-vms`
List all VMs defined in configuration.

```bash
make list-vms
```

#### `make vm-status`
Check status of deployed VMs on Proxmox.

```bash
make vm-status
```

#### `make start-vms`
Start all deployed VMs.

```bash
make start-vms
```

#### `make stop-vms`
Stop all deployed VMs.

```bash
make stop-vms
```

### Configuration Management

#### `make edit-config`
Edit VM configuration file (`vars/vm_config.yml`).

```bash
make edit-config
```

Uses `$EDITOR` environment variable (defaults to `vim`).

#### `make edit-inventory`
Edit Proxmox inventory file.

```bash
make edit-inventory
```

#### `make edit-vm-inventory`
Edit VM inventory file (for configure step).

```bash
make edit-vm-inventory
```

#### `make edit-env`
Edit environment variables file.

```bash
make edit-env
```

#### `make generate-config`
Generate `vm_config.yml` from environment variables.

```bash
make generate-config
```

#### `make generate-inventory`
Generate inventory from environment variables.

```bash
make generate-inventory
```

### Testing & Validation

#### `make test-connection`
Test SSH connection to Proxmox host.

```bash
make test-connection
```

#### `make test-vm-connection`
Test SSH connections to all deployed VMs.

```bash
make test-vm-connection
```

#### `make check-syntax`
Validate Ansible playbook syntax.

```bash
make check-syntax
```

#### `make dry-run`
Run complete deployment in check mode (no changes).

```bash
make dry-run
```

### Update Operations

#### `make update`
Update all VMs with latest packages.

```bash
make update

# With verbose output
make update VERBOSE=2
```

#### `make update-vm`
Update specific VM by hostname.

```bash
make update-vm VM=ceph-node1

# With options
make update-vm VM=ceph-node2 VERBOSE=2
```

### Utility Commands

#### `make status`
Show current deployment status and configuration.

```bash
make status
```

Output includes:
- Configuration file status
- Proxmox host and node
- Storage configuration

#### `make info`
Show detailed configuration information.

```bash
make info
```

Displays:
- Proxmox settings
- Storage configuration
- Network configuration
- VM defaults
- GitHub integration status

#### `make clean`
Clean up generated files.

```bash
make clean
```

Removes:
- `*.retry` files
- Python bytecode (`*.pyc`)
- `__pycache__` directories

## Options and Flags

### VERBOSE

Add Ansible verbosity for debugging.

```bash
VERBOSE=1    # -v (basic)
VERBOSE=2    # -vv (moderate)
VERBOSE=3    # -vvv (detailed)
```

Examples:
```bash
make deploy VERBOSE=2
make configure VERBOSE=3
make remove CONFIRM_DELETE=true VERBOSE=1
```

### CHECK

Run in check mode (dry-run) - no changes made.

```bash
CHECK=1
```

Examples:
```bash
make deploy CHECK=1
make configure CHECK=1
make deploy-full CHECK=1
```

### DIFF

Show differences in files that would be changed.

```bash
DIFF=1
```

Examples:
```bash
make configure DIFF=1
make configure CHECK=1 DIFF=1  # Dry-run with diff
```

### CONFIRM_DELETE

Required for VM removal operations.

```bash
CONFIRM_DELETE=true
```

Example:
```bash
make remove CONFIRM_DELETE=true
```

## Combining Options

You can combine multiple options:

```bash
# Verbose dry-run with diff
make configure VERBOSE=2 CHECK=1 DIFF=1

# Verbose deployment
make deploy VERBOSE=3

# Verbose removal
make remove CONFIRM_DELETE=true VERBOSE=1
```

## Environment Variables

The Makefile automatically loads variables from `.env` file:

### Required Variables

```bash
PROXMOX_API_HOST        # Proxmox host address
PROXMOX_API_USER        # Proxmox API user
PROXMOX_API_PASSWORD    # Proxmox API password
PROXMOX_NODE            # Proxmox node name
STORAGE_POOL            # Storage pool name
```

### Optional Variables

```bash
GITHUB_USERNAME         # For SSH key import
DATA_DISK_SIZE         # Size of data disks (default: 1000G)
MON_DISK_SIZE          # Size of mon disk (default: 100G)
VM_DEFAULT_MEMORY      # Default VM memory in MB
VM_DEFAULT_CORES       # Default CPU cores
PRIVATE_BRIDGE         # Private network bridge
PUBLIC_BRIDGE          # Public network bridge
```

## Workflow Examples

### Example 1: First-Time Setup

```bash
# 1. Initialize
make init
make edit-env

# 2. Verify configuration
make status
make info

# 3. Test connection
make test-connection

# 4. Upload and build image
make upload-kiwi
make build-image

# 5. Check image
make check-image

# 6. Deploy
make deploy VERBOSE=1

# 7. Configure
make edit-vm-inventory  # Add VM IPs
make configure VERBOSE=1

# 8. Verify
make test-vm-connection
make vm-status
```

### Example 2: Redeploy After Changes

```bash
# 1. Remove existing VMs
make remove CONFIRM_DELETE=true

# 2. Update configuration
make edit-config

# 3. Deploy with new settings
make deploy-full VERBOSE=2

# 4. Verify
make vm-status
```

### Example 3: Testing Changes

```bash
# 1. Check syntax
make check-syntax

# 2. Dry-run deployment
make deploy CHECK=1 DIFF=1

# 3. Dry-run configuration
make configure CHECK=1 DIFF=1

# 4. If satisfied, deploy for real
make deploy-full
```

### Example 4: Maintenance

```bash
# Check VM status
make vm-status

# Update all VMs
make update

# Update specific VM
make update-vm VM=ceph-node1

# Stop VMs for maintenance
make stop-vms

# Start VMs after maintenance
make start-vms
```

### Example 5: Troubleshooting

```bash
# Test connections
make test-connection
make test-vm-connection

# Show current status
make status
make info

# Deploy with maximum verbosity
make deploy VERBOSE=3

# Check what would change
make configure CHECK=1 DIFF=1
```

## Tips and Best Practices

### 1. Always Start with Status

```bash
make status
```

Verify your configuration before deployment.

### 2. Use Check Mode for Testing

```bash
make deploy CHECK=1
```

See what would happen without making changes.

### 3. Use Verbosity for Troubleshooting

```bash
make deploy VERBOSE=2
```

Get more detailed output when debugging issues.

### 4. Test Connections First

```bash
make test-connection
```

Verify connectivity before attempting deployment.

### 5. Keep Environment Organized

```bash
# Use version control for .env (encrypted)
# Or keep .env local and document required values
cp .env.example .env
```

### 6. Regular Updates

```bash
# Schedule regular VM updates
make update
```

### 7. Clean Up Regularly

```bash
make clean
```

Remove temporary files and artifacts.

## Troubleshooting

### "ERROR: .env file not found!"

```bash
make init
make edit-env
```

### "ERROR: Image not found"

```bash
make check-image
# If missing:
make upload-kiwi
make build-image
```

### "ERROR: VM deletion not confirmed!"

Must use explicit confirmation:
```bash
make remove CONFIRM_DELETE=true
```

### Connection Failures

```bash
# Test connections
make test-connection

# Verify inventory
make edit-inventory

# Check with verbose output
make test-connection VERBOSE=3
```

### Ansible Errors

```bash
# Check syntax
make check-syntax

# Run with maximum verbosity
make deploy VERBOSE=3

# Try dry-run first
make deploy CHECK=1
```

## Advanced Usage

### Custom Ansible Options

You can pass additional options through ANSIBLE_OPTS:

```bash
make deploy ANSIBLE_OPTS="--tags=network"
```

### Using Different Inventories

Edit the Makefile to change inventory files:

```makefile
INVENTORY := my-custom-inventory.ini
```

### Customizing Editor

```bash
export EDITOR=nano
make edit-config
```

## Integration with CI/CD

The Makefile can be used in CI/CD pipelines:

```yaml
# Example GitLab CI
deploy:
  script:
    - cp .env.production .env
    - make test-connection
    - make deploy
```

```yaml
# Example GitHub Actions
- name: Deploy VMs
  run: |
    echo "${{ secrets.ENV_FILE }}" > .env
    make deploy VERBOSE=1
```

## Summary

The Makefile provides:
- Simplified command interface
- Automatic environment loading
- Error checking and validation
- Organized workflows
- Consistent option handling
- Clear documentation

For detailed help on any command:
```bash
make help
```

For direct Ansible usage, see [README.md](README.md#alternative-direct-ansible-usage).
