# Makefile Wrapper for VM Deployment

This project now includes a comprehensive Makefile that wraps all Ansible operations with convenient commands.

## Quick Reference

### Get Started
```bash
make help          # Show all available commands
make init          # Create .env from template
make status        # Check configuration status
make info          # Show detailed configuration
```

### Deploy VMs
```bash
make deploy        # Deploy VMs to Proxmox
make configure     # Configure deployed VMs
make deploy-full   # Deploy + configure in one step
make all           # Complete workflow (check + deploy + configure)
```

### Manage VMs
```bash
make vm-status     # Check VM status
make start-vms     # Start all VMs
make stop-vms      # Stop all VMs
make update        # Update all VMs
make remove CONFIRM_DELETE=true  # Remove VMs
```

### Test & Validate
```bash
make test-connection      # Test Proxmox connection
make test-vm-connection   # Test VM connections
make check-syntax         # Validate playbooks
make dry-run             # Full deployment dry-run
```

## Key Features

### 1. Environment Variable Loading
Automatically loads configuration from `.env`:

```bash
make init        # Creates .env from .env.example
make edit-env    # Edit configuration
```

### 2. Flexible Options
Add options to any command:

```bash
VERBOSE=1/2/3           # Add verbosity
CHECK=1                 # Dry-run mode
DIFF=1                  # Show differences
CONFIRM_DELETE=true     # Required for VM removal
```

Examples:
```bash
make deploy VERBOSE=2           # Deploy with verbose output
make configure CHECK=1          # Dry-run configuration
make configure CHECK=1 DIFF=1   # Dry-run with diff
make remove CONFIRM_DELETE=true # Remove VMs (requires confirmation)
```

### 3. Safety Features
- Requires explicit confirmation for VM deletion
- Check mode for dry-runs
- Environment validation before operations
- Image existence verification before deployment

### 4. Color-Coded Output
- Blue: Informational messages
- Green: Success messages
- Yellow: Warnings
- Red: Errors

### 5. Organized Commands
Commands grouped by category:
- Main Operations
- Image Management
- VM Operations
- Configuration
- Testing & Validation
- Update Operations
- Utility

## Common Workflows

### First-Time Deployment
```bash
make init                  # Create .env
make edit-env             # Configure settings
make test-connection      # Verify Proxmox access
make upload-kiwi          # Upload KIWI files
make build-image          # Build OpenSUSE image (15-40 min)
make check-image          # Verify image exists
make deploy               # Deploy VMs
make edit-vm-inventory    # Update with VM IPs
make configure            # Configure VMs
```

### Quick Redeploy
```bash
make remove CONFIRM_DELETE=true
make deploy-full
```

### Testing Changes
```bash
make check-syntax         # Validate syntax
make deploy CHECK=1       # Dry-run
make deploy              # Deploy for real
```

### Maintenance
```bash
make vm-status           # Check status
make update              # Update all VMs
make update-vm VM=ceph-node1  # Update specific VM
```

## Documentation

### Main Documentation
- [README.md](README.md) - Complete project documentation
- [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) - Detailed Makefile usage guide
- [.env.example](.env.example) - Configuration template

### Quick References
- Run `make help` for command list
- Run `make status` for environment status
- Run `make info` for detailed configuration

## Comparison: Make vs Direct Ansible

### With Make
```bash
make deploy VERBOSE=2
make configure CHECK=1
make remove CONFIRM_DELETE=true
```

### Direct Ansible
```bash
ansible-playbook -i inventory.ini deploy-vms.yml -vv
ansible-playbook -i inventory-vms.ini configure-vms.yml --check
ansible-playbook -i inventory.ini remove-vms.yml -e "confirm_deletion=true"
```

### Benefits of Make Wrapper
- Shorter commands
- Automatic environment loading
- Consistent option handling
- Built-in validation
- Color-coded output
- Self-documenting (make help)
- Safety checks (confirmation required for deletion)

## Environment Variables

The `.env` file contains all configuration:

### Required
```bash
PROXMOX_API_HOST        # Proxmox server address
PROXMOX_API_USER        # API username
PROXMOX_API_PASSWORD    # API password
PROXMOX_NODE            # Proxmox node name
STORAGE_POOL            # Storage pool name
```

### Optional
```bash
GITHUB_USERNAME         # For SSH key import
DATA_DISK_SIZE         # Data disk size (default: 1000G)
MON_DISK_SIZE          # Mon disk size (default: 100G)
VM_DEFAULT_MEMORY      # VM memory in MB (default: 16384)
VM_DEFAULT_CORES       # CPU cores (default: 4)
PRIVATE_BRIDGE         # Private network bridge
PUBLIC_BRIDGE          # Public network bridge
NUM_VMS                # Number of VMs to deploy (1-4)
```

## Complete Command Reference

### Main Operations
| Command | Description |
|---------|-------------|
| `make help` | Display help message |
| `make all` | Full deployment workflow |
| `make deploy` | Deploy VMs to Proxmox |
| `make configure` | Configure deployed VMs |
| `make deploy-full` | Deploy + configure |
| `make remove` | Remove VMs (requires CONFIRM_DELETE=true) |

### Image Management
| Command | Description |
|---------|-------------|
| `make build-image` | Build OpenSUSE image |
| `make check-image` | Verify image exists |
| `make upload-kiwi` | Upload KIWI to Proxmox |

### VM Operations
| Command | Description |
|---------|-------------|
| `make list-vms` | List configured VMs |
| `make vm-status` | Check VM status |
| `make start-vms` | Start all VMs |
| `make stop-vms` | Stop all VMs |

### Configuration
| Command | Description |
|---------|-------------|
| `make edit-config` | Edit VM config |
| `make edit-inventory` | Edit Proxmox inventory |
| `make edit-vm-inventory` | Edit VM inventory |
| `make edit-env` | Edit environment |
| `make generate-config` | Generate config from env |
| `make generate-inventory` | Generate inventory from env |

### Testing & Validation
| Command | Description |
|---------|-------------|
| `make test-connection` | Test Proxmox connection |
| `make test-vm-connection` | Test VM connections |
| `make check-syntax` | Validate playbook syntax |
| `make dry-run` | Full deployment dry-run |

### Update Operations
| Command | Description |
|---------|-------------|
| `make update` | Update all VMs |
| `make update-vm VM=hostname` | Update specific VM |

### Utility
| Command | Description |
|---------|-------------|
| `make status` | Show deployment status |
| `make info` | Show detailed config |
| `make clean` | Clean generated files |
| `make init` | Initialize .env file |

## Examples

### Example 1: New Deployment
```bash
# Setup
make init
make edit-env

# Verify
make status
make test-connection

# Build image (one-time)
make upload-kiwi
make build-image

# Deploy
make deploy VERBOSE=1
make edit-vm-inventory
make configure VERBOSE=1

# Verify
make vm-status
make test-vm-connection
```

### Example 2: Update Configuration and Redeploy
```bash
# Update config
make edit-env
make edit-config

# Remove old VMs
make remove CONFIRM_DELETE=true

# Deploy with new config
make deploy-full VERBOSE=2

# Verify
make vm-status
```

### Example 3: Testing Before Production
```bash
# Validate
make check-syntax

# Dry-run
make deploy CHECK=1 DIFF=1
make configure CHECK=1 DIFF=1

# Deploy
make deploy-full

# Verify
make test-vm-connection
```

### Example 4: Maintenance Operations
```bash
# Check status
make vm-status

# Update packages
make update VERBOSE=1

# Update specific VM
make update-vm VM=ceph-node1 VERBOSE=1

# Stop for maintenance
make stop-vms

# Start after maintenance
make start-vms
```

## Troubleshooting

### Common Issues

#### "ERROR: .env file not found!"
```bash
make init
make edit-env
```

#### "ERROR: Image not found"
```bash
make upload-kiwi
make build-image
make check-image
```

#### "ERROR: VM deletion not confirmed!"
```bash
make remove CONFIRM_DELETE=true
```

#### Connection Issues
```bash
make test-connection VERBOSE=3
make edit-inventory
```

### Debug Mode
Use verbose output for troubleshooting:
```bash
make deploy VERBOSE=3        # Maximum verbosity
make configure VERBOSE=2     # Moderate verbosity
```

### Dry-Run Mode
Test without making changes:
```bash
make deploy CHECK=1 DIFF=1   # See what would change
```

## Tips and Best Practices

1. **Always check status first**
   ```bash
   make status
   ```

2. **Use check mode for testing**
   ```bash
   make deploy CHECK=1
   ```

3. **Test connections before deployment**
   ```bash
   make test-connection
   ```

4. **Use verbose output for troubleshooting**
   ```bash
   make deploy VERBOSE=2
   ```

5. **Regular updates**
   ```bash
   make update
   ```

6. **Clean up regularly**
   ```bash
   make clean
   ```

7. **Keep .env secure**
   - Don't commit .env to git (use .env.example)
   - Use proper file permissions (600)
   - Document required values

## Integration

### CI/CD Pipelines

#### GitLab CI
```yaml
deploy:
  script:
    - cp .env.production .env
    - make test-connection
    - make deploy VERBOSE=1
```

#### GitHub Actions
```yaml
- name: Deploy VMs
  run: |
    echo "${{ secrets.ENV_FILE }}" > .env
    make deploy-full VERBOSE=1
```

### Shell Scripts
```bash
#!/bin/bash
# deploy.sh

# Load environment
source .env

# Run deployment
make deploy-full VERBOSE=2

# Verify
make test-vm-connection
```

## Support

For detailed documentation:
- Run `make help` for command list
- See [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) for complete guide
- See [README.md](README.md) for project documentation

## Summary

The Makefile provides:
- ✅ Simplified command interface
- ✅ Automatic environment loading
- ✅ Built-in validation and safety checks
- ✅ Flexible options (verbose, check, diff)
- ✅ Organized workflow
- ✅ Self-documenting help system
- ✅ Color-coded output
- ✅ Both Make and direct Ansible usage supported

Get started:
```bash
make help
make init
make status
```
