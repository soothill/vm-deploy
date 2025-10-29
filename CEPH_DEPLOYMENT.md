# Ceph Deployment Guide

<!-- Copyright (c) 2025 Darren Soothill -->
<!-- Email: darren [at] soothill [dot] com -->
<!-- License: MIT -->

Complete guide to deploying a Ceph storage cluster on the deployed OpenSUSE VMs.

## Overview

This project now includes automated Ceph cluster deployment using `cephadm`. The Ceph packages are pre-installed in the KIWI image, ensuring all VMs have the necessary software.

### Architecture

- **Ceph Version**: Squid (19.2.x) - Latest stable release
- **Deployment Tool**: cephadm (containerized Ceph deployment)
- **Container Runtime**: Podman
- **Time Sync**: Chrony (critical for Ceph)

### Disk Layout for Ceph

Each VM has disks allocated for different purposes:

| Disk | Device | Size | Purpose | Ceph Usage |
|------|--------|------|---------|------------|
| OS | /dev/sda (scsi0) | 50GB | Boot disk | Not used by Ceph |
| Data 1 | /dev/sdb (scsi1) | Configurable | Storage | **OSD** |
| Data 2 | /dev/sdc (scsi2) | Configurable | Storage | **OSD** |
| Data 3 | /dev/sdd (scsi3) | Configurable | Storage | **OSD** |
| Data 4 | /dev/sde (scsi4) | Configurable | Storage | **OSD** |
| Mon | /dev/sdf (scsi5) | 100GB | Metadata | **OSD or MON** |

**Note**: All data disks are intentionally left unformatted - Ceph manages them directly.

## Prerequisites

### 1. Image Must Include Ceph Packages

The KIWI image includes these Ceph-related packages:

```xml
<!-- Ceph prerequisites and deployment tools -->
<package name="cephadm"/>
<package name="ceph-common"/>
<package name="podman"/>
<package name="chrony"/>
```

**Note**: Additional dependencies (Python packages, container tools) are automatically installed by cephadm during cluster bootstrap. The base image only needs the core packages listed above.

### 2. Rebuild Image if Needed

If your current image doesn't have Ceph packages:

```bash
# Check if packages are installed (on any VM)
ssh root@<vm-ip> "rpm -q cephadm ceph-common podman"

# If missing, rebuild the image
make remove-build-vm                    # Clean old build VM
make deploy-build-vm                    # Deploy fresh build VM
make build-image-remote                 # Build image with Ceph packages (20-45 min)

# Redeploy VMs with new image
make cleanup-vms CONFIRM_DELETE=true    # Remove old VMs
make deploy                             # Deploy with new image
```

### 3. VMs Must Be Running

```bash
# Deploy VMs if not already done (auto-detects IPs)
make deploy

# Verify all VMs are accessible
make test-vm-connection
```

## Quick Start

### Full Deployment (VMs + Ceph)

```bash
# 1. Setup and build image (one-time)
make init && make edit-env
make deploy-build-vm && make build-image-remote

# 2. Deploy VMs (auto-detects IPs after boot)
make deploy

# 3. Deploy Ceph cluster
make deploy-ceph
```

### Ceph Only (VMs Already Deployed)

```bash
# Deploy Ceph on existing VMs
make deploy-ceph
```

## Configuration

### Environment Variables

Add these to your `.env` file:

```bash
# ====================
# CEPH CONFIGURATION
# ====================

# Ceph version (squid=19.2.x)
export CEPH_VERSION="squid"

# Ceph admin node (first VM by default)
export CEPH_ADMIN_NODE="ceph-node1"

# Networks (auto-detected if not set)
# export CEPH_CLUSTER_NETWORK="192.168.1.0/24"  # Private network for OSD traffic
# export CEPH_PUBLIC_NETWORK="192.168.0.0/24"   # Public network for client traffic

# Deployment options
export CEPH_SKIP_MONITORING="true"      # Skip Prometheus/Grafana initially
export CEPH_SKIP_DASHBOARD="false"      # Install Ceph dashboard
export CEPH_ALLOW_FQDN="true"           # Allow FQDN hostnames
```

## Deployment Steps

The `make deploy-ceph` command runs the `deploy-ceph.yml` playbook, which performs these steps:

### 1. Prepare All Nodes

- ✅ Verify Ceph packages are installed
- ✅ Ensure time synchronization (chronyd)
- ✅ Start Podman container runtime
- ✅ Check available disks

### 2. Bootstrap Cluster (Admin Node)

- ✅ Bootstrap Ceph cluster with `cephadm`
- ✅ Configure cluster and public networks
- ✅ Create initial MON and MGR services
- ✅ Wait for cluster to be ready

### 3. Add Additional Nodes

- ✅ Distribute Ceph SSH keys
- ✅ Add each node to the cluster
- ✅ Deploy MON daemons

### 4. Configure OSDs

- ✅ Detect available devices (sdb, sdc, sdd, sde)
- ✅ Create OSDs on each device
- ✅ Wait for OSDs to be up

### 5. Verify Deployment

- ✅ Check cluster health
- ✅ Display OSD tree
- ✅ Show cluster status

## Post-Deployment

### Check Cluster Status

```bash
# SSH to admin node (first VM)
ssh root@<first-vm-ip>

# Check overall cluster health
ceph -s

# Watch cluster in real-time
ceph -w

# Check OSD status
ceph osd tree
ceph osd status

# Check MON status
ceph mon stat

# Check disk usage
ceph df
```

### Expected Output

```
  cluster:
    id:     <cluster-uuid>
    health: HEALTH_OK

  services:
    mon: 4 daemons, quorum <node1,node2,node3,node4>
    mgr: <node1>(active), standbys: <node2, node3, node4>
    osd: 16 osds: 16 up, 16 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   <used> / <total>
    pgs:
```

### Create Storage Pools

```bash
# Create a replicated pool (3 replicas)
ceph osd pool create mypool 128 128

# Set pool replicas
ceph osd pool set mypool size 3
ceph osd pool set mypool min_size 2

# Enable pool for RBD
ceph osd pool application enable mypool rbd

# Create an erasure-coded pool
ceph osd pool create ec-pool 128 erasure

# List pools
ceph osd lspools
```

### Enable Ceph Dashboard (Optional)

```bash
# Enable dashboard module
ceph mgr module enable dashboard

# Create self-signed certificate
ceph dashboard create-self-signed-cert

# Create admin user
ceph dashboard ac-user-create admin <password> administrator

# Get dashboard URL
ceph mgr services

# Access at: https://<admin-node-ip>:8443
```

### Enable Monitoring Stack (Optional)

```bash
# Deploy Prometheus, Grafana, Alertmanager
ceph orch apply prometheus --placement="count:1"
ceph orch apply grafana --placement="count:1"
ceph orch apply alertmanager --placement="count:1"

# Check services
ceph orch ls

# Access Grafana at: http://<admin-node-ip>:3000
# Default credentials: admin/admin
```

## Troubleshooting

### Packages Missing

**Problem**: `ERROR: Required Ceph packages are not installed!`

**Solution**:
```bash
# Rebuild image with Ceph packages
make build-image-remote

# Redeploy VMs
make cleanup-vms CONFIRM_DELETE=true && make deploy

# Try again
make deploy-ceph
```

### Time Synchronization Issues

**Problem**: `HEALTH_WARN clock skew detected`

**Solution**:
```bash
# Check time on all nodes
ansible -i inventory-vms.ini ceph_nodes -a "date"

# Restart chronyd on all nodes
ansible -i inventory-vms.ini ceph_nodes -b -a "systemctl restart chronyd"

# Force time sync
ansible -i inventory-vms.ini ceph_nodes -b -a "chronyc makestep"
```

### OSD Creation Failed

**Problem**: OSDs fail to create

**Solution**:
```bash
# Check disk status on a node
ssh root@<node-ip>
lsblk
ceph-volume lvm list

# Manually zap and recreate OSD
ceph-volume lvm zap /dev/sdb --destroy
ceph orch daemon add osd <node>:/dev/sdb
```

### Network Issues

**Problem**: MONs can't reach each other

**Solution**:
```bash
# Check firewall (should be disabled)
ansible -i inventory-vms.ini ceph_nodes -b -a "systemctl status firewalld"

# Check network connectivity
ansible -i inventory-vms.ini ceph_nodes -a "ping -c 2 <admin-node-ip>"

# Verify network configuration
ansible -i inventory-vms.ini ceph_nodes -a "ip addr show"
```

### Bootstrap Failed

**Problem**: `cephadm bootstrap` fails

**Solution**:
```bash
# Remove partial bootstrap
ssh root@<admin-node>
cephadm rm-cluster --force --fsid <cluster-id>

# Try again manually
cephadm bootstrap --mon-ip <admin-node-ip> --cluster-network <network>

# Or re-run playbook
make deploy-ceph
```

## Manual Deployment (Without Ansible)

If you prefer manual deployment:

### 1. Prepare All Nodes

```bash
# On each node
systemctl enable --now chronyd
systemctl enable --now podman
```

### 2. Bootstrap on Admin Node

```bash
# On first node
cephadm bootstrap \
  --mon-ip <admin-node-ip> \
  --cluster-network <private-network/mask> \
  --skip-monitoring-stack \
  --allow-fqdn-hostname

# Wait for cluster to be ready
ceph -s
```

### 3. Add Nodes

```bash
# Copy SSH key to other nodes
ssh-copy-id -f -i /etc/ceph/ceph.pub root@<node2-ip>
ssh-copy-id -f -i /etc/ceph/ceph.pub root@<node3-ip>
ssh-copy-id -f -i /etc/ceph/ceph.pub root@<node4-ip>

# Add nodes to cluster
ceph orch host add <node2> <node2-ip>
ceph orch host add <node3> <node3-ip>
ceph orch host add <node4> <node4-ip>

# Verify hosts
ceph orch host ls
```

### 4. Add OSDs

```bash
# List available devices
ceph orch device ls

# Add all available devices
ceph orch apply osd --all-available-devices

# Or add specific devices
ceph orch daemon add osd <node>:/dev/sdb
ceph orch daemon add osd <node>:/dev/sdc
# ... repeat for all devices
```

## Performance Tuning

### OSD Tuning

```bash
# Set optimal OSD parameters
ceph config set osd osd_max_backfills 2
ceph config set osd osd_recovery_max_active 3
ceph config set osd osd_recovery_op_priority 3
```

### Network Tuning

```bash
# On all nodes, add to /etc/sysctl.d/99-ceph.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Apply
sysctl -p /etc/sysctl.d/99-ceph.conf
```

## Maintenance

### Cluster Health Checks

```bash
# Daily health check
ceph health detail

# Check for slow ops
ceph health detail | grep slow

# Review cluster logs
ceph log last 100
```

### Backup Configuration

```bash
# Backup Ceph configuration
scp root@<admin-node>:/etc/ceph/ceph.conf ./backups/
scp root@<admin-node>:/etc/ceph/ceph.client.admin.keyring ./backups/
```

### Upgrade Ceph

```bash
# Check current version
ceph versions

# Upgrade to new version
ceph orch upgrade start --ceph-version <version>

# Monitor upgrade progress
ceph orch upgrade status

# Pause upgrade if needed
ceph orch upgrade pause
```

## Next Steps

1. **Create Storage Pools** for your applications
2. **Enable Dashboard** for web-based management
3. **Configure RBD** for block storage
4. **Configure CephFS** for file storage
5. **Enable RGW** for object storage (S3/Swift)

## References

- [Ceph Documentation](https://docs.ceph.com/)
- [Cephadm Documentation](https://docs.ceph.com/en/reef/cephadm/)
- [Ceph Best Practices](https://docs.ceph.com/en/reef/rados/configuration/ceph-conf/)
- [OpenSUSE Ceph Wiki](https://en.opensuse.org/openSUSE:Ceph)

## Summary

This automated deployment creates a fully functional Ceph cluster with:

- ✅ Ceph Squid (19.2.x) pre-installed in VM image
- ✅ 4-node cluster with high availability
- ✅ 16 OSDs (4 per node) for distributed storage
- ✅ MON quorum across all nodes
- ✅ MGR active/standby configuration
- ✅ Time synchronization via chrony
- ✅ Container-based deployment via Podman

Total deployment time: **5-10 minutes** (after VMs are running)
