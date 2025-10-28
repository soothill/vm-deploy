# Environment Configuration Management

This guide explains how to manage your `.env` configuration file, especially when updating to new versions of the project.

## Overview

The project uses a `.env` file for configuration. When the project is updated with new features, `.env.example` may contain new configuration variables. The `update-env` tool helps you add these new variables to your existing `.env` without losing your customizations.

## The Problem

When you update the project (git pull), `.env.example` may have:
- New configuration variables
- Updated default values
- New configuration sections
- Better comments and documentation

**BUT** you don't want to:
- Lose your existing configuration
- Manually compare files
- Risk overwriting your custom values

## The Solution: `make update-env`

The `update-env` command intelligently merges new variables from `.env.example` into your `.env` file while preserving all your existing values.

## Usage

### Basic Update

```bash
# Pull latest changes
git pull

# Update your .env with new variables
make update-env
```

### What It Does

1. **Analyzes Both Files**
   - Reads your current `.env`
   - Reads the latest `.env.example`
   - Identifies new variables
   - Identifies changed defaults (informational only)

2. **Creates Backup**
   - Automatically backs up your `.env`
   - Backup filename: `.env.backup.YYYYMMDD_HHMMSS`
   - Safe to revert if needed

3. **Shows Preview**
   - Lists all new variables found
   - Shows which defaults have changed
   - Asks for confirmation before changes

4. **Adds Missing Variables**
   - Preserves ALL your existing values
   - Only adds new variables you don't have
   - Includes comments from `.env.example`
   - Maintains proper section organization

5. **Reports Results**
   - Shows what was added
   - Provides backup location
   - Suggests next steps

## Example Session

```bash
$ make update-env

==========================================
Environment Configuration Update
==========================================

✓ Found existing .env file
Analyzing differences...

✓ Backup created: .env.backup.20250128_103045

Found 3 new variable(s) in .env.example:
  - BUILD_VM_ID
  - BUILD_VM_NAME
  - BUILD_VM_MEMORY

Note: 2 variable(s) have new defaults in .env.example:
(Your current values will be preserved)
  - VM_DEFAULT_MEMORY:
    Current: 16384
    Example: 32768
  - VM_DEFAULT_CORES:
    Current: 4
    Example: 8

Do you want to add new variables to your .env?
Your existing values will NOT be changed.
Continue? (yes/no): yes

Updating .env file...
  + Added: BUILD_VM_ID
  + Added: BUILD_VM_NAME
  + Added: BUILD_VM_MEMORY

==========================================
✓ Update Complete!
==========================================

Summary:
  - 3 new variable(s) added
  - Existing values preserved
  - Backup saved: .env.backup.20250128_103045

Recommended Actions:
  1. Review new default values for existing variables
  2. Consider updating if appropriate:
     - VM_DEFAULT_MEMORY
     - VM_DEFAULT_CORES

Next steps:
  1. Review changes: diff .env.backup.20250128_103045 .env
  2. Edit if needed: make edit-env
  3. Verify config: make info

To revert changes: cp .env.backup.20250128_103045 .env
```

## Common Scenarios

### Scenario 1: New Feature Added

Project adds build VM support with new variables:

```bash
# Update project
git pull

# Add new variables
make update-env
# ✓ BUILD_VM_ID, BUILD_VM_NAME, etc. added

# Review and configure
make edit-env
make info
```

### Scenario 2: Defaults Changed

Project updates recommended defaults:

```bash
make update-env

# Output shows:
# Note: VM_DEFAULT_MEMORY changed from 16384 to 32768
# Your value (16384) is preserved

# Decide if you want to use new default
make edit-env
# Change if appropriate

make info
# Verify configuration
```

### Scenario 3: Already Up to Date

```bash
make update-env

# Output:
# ✓ Your .env is up to date!
# No new variables to add.
```

### Scenario 4: No Existing .env

```bash
make update-env

# Output:
# No existing .env file found.
# Creating new .env from .env.example...
# ✓ .env created successfully
```

## Manual Operations

### Direct Script Execution

```bash
./scripts/update-env.sh
```

### Review Changes

```bash
# See what was added
diff .env.backup.20250128_103045 .env

# See specific variable
grep BUILD_VM_ID .env
```

### Revert Changes

```bash
# If you're not happy with the update
cp .env.backup.20250128_103045 .env
```

### Clean Up Old Backups

```bash
# List backups
ls -lh .env.backup.*

# Remove old backups
rm .env.backup.20250120_*
```

## Best Practices

### 1. Update Regularly

```bash
# When updating project
git pull
make update-env
```

### 2. Review New Variables

```bash
# After update
make info        # See current config
make edit-env    # Adjust new variables
```

### 3. Check Defaults

When the tool reports changed defaults, consider:
- Are the new defaults better for your use case?
- Does your workload benefit from the change?
- Do you have the resources for higher defaults?

### 4. Keep Backups

Don't delete backups immediately:
```bash
# Keep recent backups for a while
ls -lht .env.backup.* | head -5
```

### 5. Document Your Changes

Add comments to your `.env`:
```bash
# In .env
export VM_DEFAULT_MEMORY="16384"  # Using 16GB for dev environment
```

## What Gets Preserved

✅ **Always Preserved:**
- Your custom variable values
- Your custom comments
- Variable order (mostly)
- File structure

✅ **Never Changed:**
- Existing variable values
- Your configuration choices

## What Gets Added

✅ **Always Added:**
- New variables from .env.example
- Comments for new variables
- Section headers for new sections

ℹ️ **Only Informational:**
- Changed default values (you decide if you want them)

## Troubleshooting

### Issue: Script Doesn't Find New Variables

**Problem:** You know there are new variables but script says up to date

**Solution:**
```bash
# Check variable format in .env.example
grep "^export" .env.example | head

# Make sure variables use 'export VAR=' format
# Not just 'VAR=' or '# export VAR='
```

### Issue: Want to Start Fresh

**Problem:** .env is messy, want clean start

**Solution:**
```bash
# Backup your important values
cp .env .env.my_values

# Start fresh
rm .env
make init

# Manually copy important values back
vim .env
```

### Issue: Backup Files Pile Up

**Solution:**
```bash
# Keep only last 5 backups
ls -t .env.backup.* | tail -n +6 | xargs rm -f
```

### Issue: Need to Compare Files

**Solution:**
```bash
# See all differences
diff .env .env.example

# See just variables
diff <(grep "^export" .env | sort) <(grep "^export" .env.example | sort)

# See your customizations
diff <(grep "^export" .env.example | sort) <(grep "^export" .env | sort)
```

## Integration with Workflows

### Updating Project

```bash
#!/bin/bash
# update-project.sh

# Pull changes
git pull

# Update environment
make update-env

# Review changes
make info

# Run any new migrations if needed
# ...
```

### CI/CD

```bash
# In CI/CD pipeline
if [ -f .env ]; then
    # Update existing config
    make update-env <<< "yes"
else
    # Create new config
    cp .env.example .env
    # Set CI/CD specific values
fi
```

## Advanced Usage

### Batch Mode (Non-Interactive)

```bash
# Auto-accept updates
echo "yes" | make update-env

# Or in script
make update-env <<< "yes"
```

### Custom Backup Location

```bash
# Modify script to use different backup location
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
# Edit scripts/update-env.sh
```

### Selective Updates

```bash
# Review specific variables before adding
./scripts/update-env.sh

# Only add specific variables
grep "^export BUILD_VM" .env.example >> .env
```

## Summary

| Command | Purpose |
|---------|---------|
| `make update-env` | Add new variables from .env.example |
| `make edit-env` | Edit your .env file |
| `make info` | View current configuration |
| `diff .env.backup.* .env` | See what changed |
| `cp .env.backup.* .env` | Revert changes |

**Key Points:**
- ✅ Safe - creates backups automatically
- ✅ Smart - only adds missing variables
- ✅ Preserves - never changes your values
- ✅ Informative - shows changed defaults
- ✅ Reversible - easy to undo

**Workflow:**
1. `git pull` - Get latest changes
2. `make update-env` - Add new variables
3. `make info` - Review configuration
4. `make edit-env` - Adjust if needed

The `update-env` tool makes it safe and easy to keep your configuration up to date! 🎉
