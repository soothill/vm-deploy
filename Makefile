.PHONY: help deploy configure remove clean build-image build-image-remote check-image \
        status test-connection generate-config generate-inventory \
        list-vms vm-status cleanup-vms generate-config-silent generate-inventory-silent \
        deploy-build-vm build-vm-status remove-build-vm detect-build-vm-ip ssh-build-vm update-env \
        fresh-start rebuild-all

# Load environment variables from .env if it exists
-include .env
export

# Ensure Python user bin is in PATH (for ansible-playbook)
export PATH := $(HOME)/Library/Python/3.13/bin:$(HOME)/.local/bin:$(PATH)

# Default target
.DEFAULT_GOAL := help

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Ansible variables
ANSIBLE := ansible-playbook
INVENTORY := inventory.ini
VM_INVENTORY := inventory-vms.ini
DEPLOY_PLAYBOOK := deploy-vms.yml
CONFIGURE_PLAYBOOK := configure-vms.yml
REMOVE_PLAYBOOK := remove-vms.yml
ANSIBLE_OPTS :=

# Image configuration with defaults
OPENSUSE_IMAGE_NAME ?= opensuse-leap-custom.qcow2
KIWI_BUILD_DIR ?= /root/kiwi
OPENSUSE_IMAGE_PATH ?= /var/lib/vz/template/iso/$(OPENSUSE_IMAGE_NAME)

# Variables for interactive options
VERBOSE ?= 0
CHECK ?= 0
DIFF ?= 0
CONFIRM_DELETE ?= false

# Add verbose flag if requested
ifeq ($(VERBOSE),1)
    ANSIBLE_OPTS += -v
endif
ifeq ($(VERBOSE),2)
    ANSIBLE_OPTS += -vv
endif
ifeq ($(VERBOSE),3)
    ANSIBLE_OPTS += -vvv
endif

# Add check mode if requested
ifeq ($(CHECK),1)
    ANSIBLE_OPTS += --check
endif

# Add diff mode if requested
ifeq ($(DIFF),1)
    ANSIBLE_OPTS += --diff
endif

##@ Help

help: ## Display this help message
	@echo "$(BLUE)OpenSUSE Ceph Cluster Deployment$(NC)"
	@echo "$(BLUE)================================$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "  1. make init                             # Create .env file"
	@echo "  2. make edit-env                         # Edit configuration"
	@echo "  3. make fresh-start CONFIRM_DELETE=true  # Build image + deploy VMs (all-in-one!)"
	@echo "  4. make configure                        # Configure VMs"
	@echo ""
	@echo "$(BLUE)Or step by step:$(NC)"
	@echo "  make deploy-build-vm && make build-image-remote  # Build image"
	@echo "  make deploy                                      # Deploy VMs"
	@echo ""
	@echo "$(BLUE)Note:$(NC) All config is controlled by .env - deploy auto-generates Ansible configs"
	@echo ""

##@ Main Operations

deploy: check-env generate-config-silent generate-inventory-silent check-image ## Deploy VMs to Proxmox
	@echo "$(BLUE)Deploying VMs to Proxmox...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) $(DEPLOY_PLAYBOOK) $(ANSIBLE_OPTS)
	@echo "$(GREEN)VM deployment completed!$(NC)"

configure: check-env ## Configure deployed VMs (updates, SSH keys, services)
	@echo "$(BLUE)Configuring deployed VMs...$(NC)"
	@$(ANSIBLE) -i $(VM_INVENTORY) $(CONFIGURE_PLAYBOOK) $(ANSIBLE_OPTS)
	@echo "$(GREEN)VM configuration completed!$(NC)"

remove: check-env ## Remove VMs from Proxmox (requires CONFIRM_DELETE=true)
ifeq ($(CONFIRM_DELETE),true)
	@echo "$(RED)Removing VMs...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) $(REMOVE_PLAYBOOK) $(ANSIBLE_OPTS) -e "confirm_deletion=true"
	@echo "$(GREEN)VMs removed successfully$(NC)"
else
	@echo "$(RED)ERROR: VM deletion not confirmed!$(NC)"
	@echo "To delete VMs, run: make remove CONFIRM_DELETE=true"
	@exit 1
endif

cleanup-vms: check-env ## Quick cleanup - destroy all VMs and disks (requires CONFIRM_DELETE=true)
ifeq ($(CONFIRM_DELETE),true)
	@echo "$(RED)Destroying VMs and cleaning up disks...$(NC)"
	@echo "$(YELLOW)This will forcefully destroy all VMs defined in your configuration$(NC)"
	@echo ""
	@. .env && \
	for vmid in $$(seq 1 $${NUM_VMS:-4}); do \
		eval "VMID=\$$VM$${vmid}_VMID"; \
		if [ -z "$$VMID" ]; then \
			VMID=$$((199 + vmid)); \
		fi; \
		echo "  Destroying VM $$VMID..."; \
		ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm stop $$VMID 2>/dev/null; qm destroy $$VMID 2>/dev/null || echo '  VM $$VMID not found (already removed)'"; \
	done
	@echo ""
	@echo "$(GREEN)Cleanup completed!$(NC)"
	@echo "$(YELLOW)Note: ZFS snapshots may still exist. To fully clean ZFS:$(NC)"
	@echo "  ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) 'zfs list -t all | grep vm-'"
else
	@echo "$(RED)ERROR: VM deletion not confirmed!$(NC)"
	@echo ""
	@echo "This command will DESTROY VMs and all their disks without backup."
	@echo "To proceed, run: $(GREEN)make cleanup-vms CONFIRM_DELETE=true$(NC)"
	@echo ""
	@echo "To see what VMs would be deleted:"
	@echo "  make list-vms"
	@exit 1
endif

fresh-start: check-env ## Complete fresh deployment: rebuild image + redeploy VMs (requires CONFIRM_DELETE=true)
ifeq ($(CONFIRM_DELETE),true)
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Starting Fresh Deployment$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)This will:$(NC)"
	@echo "  1. Remove build VM"
	@echo "  2. Deploy new build VM"
	@echo "  3. Build OpenSUSE image with LLDP/Avahi"
	@echo "  4. Remove existing VMs"
	@echo "  5. Deploy new VMs"
	@echo ""
	@echo "$(YELLOW)Step 1/5: Removing build VM...$(NC)"
	@$(MAKE) remove-build-vm || echo "Build VM not found, continuing..."
	@echo ""
	@echo "$(YELLOW)Step 2/5: Deploying build VM...$(NC)"
	@$(MAKE) deploy-build-vm
	@echo ""
	@echo "$(YELLOW)Step 3/5: Building OpenSUSE image (this takes 20-45 minutes)...$(NC)"
	@$(MAKE) build-image-remote
	@echo ""
	@echo "$(YELLOW)Step 4/5: Removing existing VMs...$(NC)"
	@$(MAKE) cleanup-vms CONFIRM_DELETE=true || echo "No VMs to remove, continuing..."
	@echo ""
	@echo "$(YELLOW)Step 5/5: Deploying VMs...$(NC)"
	@$(MAKE) deploy
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)Fresh Deployment Completed!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Update inventory-vms.ini with actual VM IPs: make edit-vm-inventory"
	@echo "  2. Configure VMs: make configure"
else
	@echo "$(RED)ERROR: Fresh deployment not confirmed!$(NC)"
	@echo ""
	@echo "$(YELLOW)This will:$(NC)"
	@echo "  - Rebuild the OpenSUSE image (20-45 minutes)"
	@echo "  - Remove and recreate ALL VMs"
	@echo "  - All VM data will be LOST"
	@echo ""
	@echo "To proceed, run: $(GREEN)make fresh-start CONFIRM_DELETE=true$(NC)"
	@exit 1
endif

rebuild-all: check-env ## Rebuild image and redeploy VMs (requires CONFIRM_DELETE=true) - alias for fresh-start
	@$(MAKE) fresh-start CONFIRM_DELETE=$(CONFIRM_DELETE)

##@ Image Management

build-image-remote: ## Build image on dedicated build VM (RECOMMENDED)
	@echo "$(BLUE)Building image on dedicated OpenSUSE build VM...$(NC)"
	@echo "$(YELLOW)This is the RECOMMENDED method for building KIWI images$(NC)"
	@echo ""
	@./build-vm/build-and-transfer.sh

build-image: ## Build OpenSUSE image on Proxmox host (legacy method)
	@echo "$(BLUE)Building OpenSUSE image on Proxmox host...$(NC)"
	@echo "This will connect to Proxmox and run the KIWI build"
	@if [ -z "$(PROXMOX_API_HOST)" ]; then \
		echo "$(RED)ERROR: PROXMOX_API_HOST not set. Create .env file first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Build configuration:$(NC)"
	@echo "  Host: $(PROXMOX_API_HOST)"
	@echo "  Build directory: $(KIWI_BUILD_DIR)"
	@echo "  Image destination: $(OPENSUSE_IMAGE_PATH)"
	@echo "  Image name: $(OPENSUSE_IMAGE_NAME)"
	@echo ""
	@echo "Connecting to $(PROXMOX_API_HOST)..."
	@ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) \
		"cd $(KIWI_BUILD_DIR) && \
		 IMAGE_PATH=$(OPENSUSE_IMAGE_PATH) IMAGE_NAME=$(OPENSUSE_IMAGE_NAME) ./build-image.sh"
	@echo "$(GREEN)Image build completed!$(NC)"
	@echo "$(GREEN)Image location: $(OPENSUSE_IMAGE_PATH)$(NC)"

check-image: check-env ## Check if OpenSUSE image exists on Proxmox
	@echo "$(BLUE)Checking for OpenSUSE image...$(NC)"
	@echo "  Host: $(PROXMOX_API_HOST)"
	@echo "  Path: $(OPENSUSE_IMAGE_PATH)"
	@echo ""
	@if ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "test -f $(OPENSUSE_IMAGE_PATH)"; then \
		echo "$(GREEN)✓ Image found at $(OPENSUSE_IMAGE_PATH)$(NC)"; \
	else \
		echo "$(RED)ERROR: Image not found at $(OPENSUSE_IMAGE_PATH)$(NC)"; \
		echo ""; \
		echo "Options:"; \
		echo "  1. Build image on dedicated build VM (recommended):"; \
		echo "     make deploy-build-vm"; \
		echo "     make build-image-remote"; \
		echo ""; \
		echo "  2. Build image directly on Proxmox:"; \
		echo "     make upload-kiwi"; \
		echo "     make build-image"; \
		echo ""; \
		echo "  3. Check if image exists at different location:"; \
		echo "     ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) 'find /var/lib/vz -name \"*.qcow2\" -type f'"; \
		echo ""; \
		exit 1; \
	fi

upload-kiwi: check-env ## Upload KIWI build directory to Proxmox
	@echo "$(BLUE)Uploading KIWI build directory to Proxmox...$(NC)"
	@echo "  Destination: $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST):$(KIWI_BUILD_DIR)"
	@ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "mkdir -p $(KIWI_BUILD_DIR)"
	@scp -r kiwi/* $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST):$(KIWI_BUILD_DIR)/
	@echo "$(GREEN)Upload completed!$(NC)"
	@echo "$(YELLOW)Build directory: $(KIWI_BUILD_DIR)$(NC)"

##@ Build VM Management

deploy-build-vm: check-env ## Deploy dedicated OpenSUSE build VM for KIWI
	@echo "$(BLUE)Deploying dedicated build VM...$(NC)"
	@echo "$(YELLOW)This creates a separate OpenSUSE VM for building images$(NC)"
	@echo ""
	@./build-vm/deploy-build-vm.sh

build-vm-status: check-env ## Check build VM status
	@echo "$(BLUE)Checking build VM status...$(NC)"
	@if [ -f build-vm/build-vm-ip.txt ]; then \
		. build-vm/build-vm-ip.txt; \
		echo "$(GREEN)Build VM Configuration:$(NC)"; \
		echo "  VM ID: $(BUILD_VM_ID)"; \
		echo "  VM Name: $(BUILD_VM_NAME)"; \
		echo "  IP Address: $$BUILD_VM_IP"; \
		echo ""; \
		ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm status $(BUILD_VM_ID)" || echo "$(RED)VM not found$(NC)"; \
	else \
		echo "$(YELLOW)Build VM not deployed yet$(NC)"; \
		echo "Run: make deploy-build-vm"; \
	fi

remove-build-vm: check-env ## Remove the build VM
	@./build-vm/remove-build-vm.sh

fix-build-vm-certs: check-env ## Fix CA certificates on existing build VM
	@./build-vm/fix-build-vm-certs.sh

fix-build-vm-kpartx: check-env ## Install missing kpartx tool on existing build VM
	@./build-vm/fix-build-vm-kpartx.sh

detect-build-vm-ip: check-env ## Auto-detect and save build VM IP address
	@echo "$(BLUE)Detecting build VM IP address...$(NC)"
	@BUILD_VM_ID=$${BUILD_VM_ID:-100}; \
	if ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm status $$BUILD_VM_ID >/dev/null 2>&1"; then \
		VM_STATUS=$$(ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm status $$BUILD_VM_ID | awk '{print \$$2}'"); \
		if [ "$$VM_STATUS" != "running" ]; then \
			echo "$(YELLOW)Build VM $$BUILD_VM_ID is not running (status: $$VM_STATUS)$(NC)"; \
			echo "Starting build VM..."; \
			ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm start $$BUILD_VM_ID"; \
			echo "Waiting 60 seconds for VM to boot..."; \
			sleep 60; \
		fi; \
		echo "Trying multiple detection methods..."; \
		VM_MAC=$$(ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm config $$BUILD_VM_ID | grep -o 'net0:.*' | grep -o '[0-9A-Fa-f:]\{17\}' | head -1"); \
		BUILD_VM_IP=$$(ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "qm guest cmd $$BUILD_VM_ID network-get-interfaces 2>/dev/null | grep -o '\"ip-address\":\"[0-9][0-9.]*\"' | grep -o '[0-9][0-9.]*' | grep -v '127.0.0.1' | grep -v ':' | head -1" || echo ""); \
		if [ -n "$$BUILD_VM_IP" ] && [ "$$BUILD_VM_IP" != "." ]; then \
			echo "$(GREEN)✓ Detected IP via guest agent: $$BUILD_VM_IP$(NC)"; \
		else \
			BUILD_VM_IP=$$(ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "ip neigh show | grep -i '$$VM_MAC' | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1" || echo ""); \
			if [ -n "$$BUILD_VM_IP" ]; then \
				echo "$(GREEN)✓ Detected IP via ARP table: $$BUILD_VM_IP$(NC)"; \
			else \
				BUILD_VM_IP=$$(ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) "grep -i '$$VM_MAC' /var/lib/misc/dnsmasq.leases 2>/dev/null | awk '{print \$$3}' | head -1" || echo ""); \
				if [ -n "$$BUILD_VM_IP" ]; then \
					echo "$(GREEN)✓ Detected IP via DHCP leases: $$BUILD_VM_IP$(NC)"; \
				fi; \
			fi; \
		fi; \
		if [ -n "$$BUILD_VM_IP" ]; then \
			echo "BUILD_VM_IP=$$BUILD_VM_IP" > build-vm/build-vm-ip.txt; \
			echo "$(GREEN)✓ Saved to build-vm/build-vm-ip.txt$(NC)"; \
		else \
			echo "$(RED)ERROR: Could not detect IP address$(NC)"; \
			echo ""; \
			echo "Tried: guest agent, ARP table (MAC: $$VM_MAC), DHCP leases"; \
			echo ""; \
			echo "Please check:"; \
			echo "  1. VM has network connectivity"; \
			echo "  2. Check console: ssh $(PROXMOX_SSH_USER)@$(PROXMOX_API_HOST) 'qm terminal $$BUILD_VM_ID'"; \
			echo "  3. Set BUILD_VM_IP manually in .env"; \
			exit 1; \
		fi; \
	else \
		echo "$(RED)ERROR: Build VM $$BUILD_VM_ID does not exist$(NC)"; \
		echo "Run: make deploy-build-vm"; \
		exit 1; \
	fi

ssh-build-vm: ## SSH into the build VM
	@if [ -f build-vm/build-vm-ip.txt ]; then \
		. build-vm/build-vm-ip.txt; \
		echo "$(BLUE)Connecting to build VM at $$BUILD_VM_IP...$(NC)"; \
		ssh root@$$BUILD_VM_IP; \
	else \
		echo "$(RED)ERROR: Build VM not deployed$(NC)"; \
		echo "Run: make deploy-build-vm"; \
		exit 1; \
	fi

##@ VM Operations

list-vms: check-env ## List all VMs defined in configuration
	@echo "$(BLUE)Configured VMs:$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) proxmox_host -m debug -a "msg={{ vms }}" --extra-vars "@vars/vm_config.yml"

vm-status: check-env ## Check status of deployed VMs
	@echo "$(BLUE)Checking VM status...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) proxmox_host -m shell -a "qm list | grep -E 'ceph-node'" $(ANSIBLE_OPTS) || true

start-vms: check-env ## Start all deployed VMs
	@echo "$(BLUE)Starting VMs...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) $(DEPLOY_PLAYBOOK) --tags start $(ANSIBLE_OPTS)
	@echo "$(GREEN)VMs started$(NC)"

stop-vms: check-env ## Stop all deployed VMs
	@echo "$(YELLOW)Stopping VMs...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) proxmox_host -m shell -a "for vm in 200 201 202 203; do qm stop \$$vm; done" $(ANSIBLE_OPTS)
	@echo "$(GREEN)VMs stopped$(NC)"

##@ Configuration

generate-config: ## Generate vm_config.yml from environment variables
	@echo "$(BLUE)Generating vm_config.yml from environment...$(NC)"
	@./generate-config.sh
	@echo "$(GREEN)Configuration generated!$(NC)"

generate-config-silent:
	@./generate-config.sh > /dev/null

generate-inventory: ## Generate inventory from environment variables
	@echo "$(BLUE)Generating inventory from environment...$(NC)"
	@./generate-inventory.sh
	@echo "$(GREEN)Inventory generated!$(NC)"

generate-inventory-silent:
	@./generate-inventory.sh > /dev/null

edit-config: ## Edit VM configuration file
	@$${EDITOR:-vim} vars/vm_config.yml

edit-inventory: ## Edit Proxmox inventory
	@$${EDITOR:-vim} $(INVENTORY)

edit-vm-inventory: ## Edit VM inventory (for configure step)
	@$${EDITOR:-vim} $(VM_INVENTORY)

edit-env: ## Edit environment variables file
	@$${EDITOR:-vim} .env

update-env: ## Update .env with new variables from .env.example
	@echo "$(BLUE)Updating .env with new variables from .env.example...$(NC)"
	@echo "$(YELLOW)This will preserve your existing values$(NC)"
	@echo ""
	@./scripts/update-env.sh

##@ Testing & Validation

test-connection: check-env ## Test connection to Proxmox host
	@echo "$(BLUE)Testing connection to Proxmox host...$(NC)"
	@ansible -i $(INVENTORY) proxmox_host -m ping $(ANSIBLE_OPTS)
	@echo "$(GREEN)Connection successful!$(NC)"

test-vm-connection: check-env ## Test connection to deployed VMs
	@echo "$(BLUE)Testing connection to VMs...$(NC)"
	@ansible -i $(VM_INVENTORY) ceph_nodes -m ping $(ANSIBLE_OPTS)
	@echo "$(GREEN)VM connections successful!$(NC)"

check-syntax: ## Check Ansible playbook syntax
	@echo "$(BLUE)Checking playbook syntax...$(NC)"
	@$(ANSIBLE) --syntax-check -i $(INVENTORY) $(DEPLOY_PLAYBOOK)
	@$(ANSIBLE) --syntax-check -i $(VM_INVENTORY) $(CONFIGURE_PLAYBOOK)
	@$(ANSIBLE) --syntax-check -i $(INVENTORY) $(REMOVE_PLAYBOOK)
	@echo "$(GREEN)Syntax check passed!$(NC)"

dry-run: check-env ## Run full deployment in check mode (no changes)
	@echo "$(BLUE)Running deployment dry-run...$(NC)"
	@$(MAKE) deploy-full CHECK=1
	@echo "$(GREEN)Dry-run completed!$(NC)"

##@ Update Operations

update: check-env ## Update all VMs (package updates)
	@echo "$(BLUE)Updating all VMs...$(NC)"
	@$(ANSIBLE) -i $(VM_INVENTORY) ceph_nodes -m community.general.zypper -a "name='*' state=latest" $(ANSIBLE_OPTS) -b
	@echo "$(GREEN)Updates completed!$(NC)"

update-vm: check-env ## Update specific VM (use VM=hostname)
ifndef VM
	@echo "$(RED)ERROR: VM not specified. Use: make update-vm VM=ceph-node1$(NC)"
	@exit 1
endif
	@echo "$(BLUE)Updating $(VM)...$(NC)"
	@$(ANSIBLE) -i $(VM_INVENTORY) $(VM) -m community.general.zypper -a "name='*' state=latest" $(ANSIBLE_OPTS) -b
	@echo "$(GREEN)Update completed for $(VM)!$(NC)"

##@ Utility

status: ## Show current deployment status
	@echo "$(BLUE)=== Environment Status ===$(NC)"
	@echo "$(GREEN)Configuration:$(NC)"
	@[ -f .env ] && echo "  .env: $(GREEN)exists$(NC)" || echo "  .env: $(RED)missing$(NC)"
	@[ -f vars/vm_config.yml ] && echo "  vm_config.yml: $(GREEN)exists$(NC)" || echo "  vm_config.yml: $(RED)missing$(NC)"
	@[ -f $(INVENTORY) ] && echo "  inventory.ini: $(GREEN)exists$(NC)" || echo "  inventory.ini: $(RED)missing$(NC)"
	@echo ""
	@echo "$(GREEN)Proxmox:$(NC)"
	@[ -n "$(PROXMOX_API_HOST)" ] && echo "  Host: $(PROXMOX_API_HOST)" || echo "  Host: $(RED)not configured$(NC)"
	@[ -n "$(PROXMOX_NODE)" ] && echo "  Node: $(PROXMOX_NODE)" || echo "  Node: $(RED)not configured$(NC)"
	@echo ""
	@echo "$(GREEN)Storage:$(NC)"
	@[ -n "$(STORAGE_POOL)" ] && echo "  Pool: $(STORAGE_POOL)" || echo "  Pool: $(RED)not configured$(NC)"
	@[ -n "$(DATA_DISK_SIZE)" ] && echo "  Data disk size: $(DATA_DISK_SIZE)" || echo "  Data disk size: $(RED)not configured$(NC)"
	@echo ""
	@echo "$(GREEN)Image:$(NC)"
	@[ -n "$(OPENSUSE_IMAGE_PATH)" ] && echo "  Path: $(OPENSUSE_IMAGE_PATH)" || echo "  Path: $(RED)not configured$(NC)"
	@[ -n "$(OPENSUSE_IMAGE_NAME)" ] && echo "  Name: $(OPENSUSE_IMAGE_NAME)" || echo "  Name: $(YELLOW)using default$(NC)"

info: ## Show detailed configuration information
	@echo "$(BLUE)=== Deployment Configuration ===$(NC)"
	@echo ""
	@echo "$(GREEN)Proxmox Settings:$(NC)"
	@echo "  API Host: $(PROXMOX_API_HOST)"
	@echo "  API User: $(PROXMOX_API_USER)"
	@echo "  Node: $(PROXMOX_NODE)"
	@echo ""
	@echo "$(GREEN)Image Configuration:$(NC)"
	@echo "  Image Path: $(OPENSUSE_IMAGE_PATH)"
	@echo "  Image Name: $(OPENSUSE_IMAGE_NAME)"
	@echo "  Build Directory: $(KIWI_BUILD_DIR)"
	@echo ""
	@echo "$(GREEN)Storage Configuration:$(NC)"
	@echo "  Storage Pool: $(STORAGE_POOL)"
	@echo "  Data Disk Size: $(DATA_DISK_SIZE)"
	@echo "  Mon Disk Size: $(MON_DISK_SIZE)"
	@echo ""
	@echo "$(GREEN)Network Configuration:$(NC)"
	@echo "  Private Bridge: $(PRIVATE_BRIDGE)"
	@echo "  Public Bridge: $(PUBLIC_BRIDGE)"
	@echo ""
	@echo "$(GREEN)VM Defaults:$(NC)"
	@echo "  Memory: $(VM_DEFAULT_MEMORY) MB"
	@echo "  CPU Cores: $(VM_DEFAULT_CORES)"
	@echo "  Number of VMs: $(NUM_VMS)"
	@echo ""
	@echo "$(GREEN)GitHub Integration:$(NC)"
	@[ -n "$(GITHUB_USERNAME)" ] && echo "  Username: $(GITHUB_USERNAME)" || echo "  Username: $(YELLOW)not configured$(NC)"

clean: ## Clean up generated files
	@echo "$(YELLOW)Cleaning up generated files...$(NC)"
	@rm -f *.retry
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -delete
	@echo "$(GREEN)Cleanup completed!$(NC)"

init: ## Initialize new deployment (create .env from example)
	@if [ -f .env ]; then \
		echo "$(YELLOW).env already exists. Skipping...$(NC)"; \
	else \
		echo "$(BLUE)Creating .env from .env.example...$(NC)"; \
		cp .env.example .env; \
		echo "$(GREEN).env created!$(NC)"; \
		echo "$(YELLOW)Please edit .env with your configuration: make edit-env$(NC)"; \
	fi

##@ Internal Targets (not meant to be called directly)

check-env: ## Check if required environment is set up
	@if [ ! -f .env ]; then \
		echo "$(RED)ERROR: .env file not found!$(NC)"; \
		echo "Run 'make init' to create it from .env.example"; \
		exit 1; \
	fi
