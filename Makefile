.PHONY: help all deploy configure remove clean build-image build-image-remote check-image \
        deploy-full status update test-connection generate-config generate-inventory \
        deploy-only configure-only remove-confirm list-vms vm-status \
        deploy-build-vm build-vm-status remove-build-vm ssh-build-vm

# Load environment variables from .env if it exists
-include .env
export

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
	@echo "$(BLUE)Options:$(NC)"
	@echo "  $(GREEN)VERBOSE=1/2/3$(NC)        Add verbosity (-v/-vv/-vvv)"
	@echo "  $(GREEN)CHECK=1$(NC)              Run in check mode (dry-run)"
	@echo "  $(GREEN)DIFF=1$(NC)               Show differences"
	@echo "  $(GREEN)CONFIRM_DELETE=true$(NC)  Confirm VM deletion (required for remove)"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make deploy              # Deploy VMs"
	@echo "  make deploy VERBOSE=2    # Deploy with verbose output"
	@echo "  make configure CHECK=1   # Dry-run configuration"
	@echo "  make remove CONFIRM_DELETE=true  # Remove VMs (requires confirmation)"
	@echo ""

##@ Main Operations

all: check-env check-image deploy configure ## Full deployment (image check + deploy + configure)
	@echo "$(GREEN)Full deployment completed!$(NC)"

deploy: check-env check-image deploy-only ## Deploy VMs to Proxmox
	@echo "$(GREEN)VM deployment completed!$(NC)"
	@echo "$(YELLOW)Next step: Update $(VM_INVENTORY) with VM IPs, then run 'make configure'$(NC)"

configure: check-env configure-only ## Configure deployed VMs (updates, SSH keys, services)
	@echo "$(GREEN)VM configuration completed!$(NC)"

deploy-full: check-env check-image deploy-only configure-only ## Deploy and configure VMs in one step
	@echo "$(GREEN)Full deployment and configuration completed!$(NC)"

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

##@ Image Management

build-image-remote: ## Build image on dedicated build VM (RECOMMENDED)
	@echo "$(BLUE)Building image on dedicated OpenSUSE build VM...$(NC)"
	@echo "$(YELLOW)This is the RECOMMENDED method for building KIWI images$(NC)"
	@echo ""
	@if [ ! -f build-vm/build-vm-ip.txt ] && [ -z "$(BUILD_VM_IP)" ]; then \
		echo "$(RED)ERROR: Build VM not configured!$(NC)"; \
		echo ""; \
		echo "Please run: make deploy-build-vm"; \
		echo "Or set BUILD_VM_IP in .env"; \
		exit 1; \
	fi
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
	@$(ANSIBLE) -i $(INVENTORY) all -m stat -a "path=$(OPENSUSE_IMAGE_PATH)" $(ANSIBLE_OPTS) > /dev/null 2>&1 || \
		(echo "$(RED)ERROR: Image not found at $(OPENSUSE_IMAGE_PATH)$(NC)" && \
		 echo "Build it with: make build-image" && exit 1)
	@echo "$(GREEN)Image found at $(OPENSUSE_IMAGE_PATH)$(NC)"

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

generate-inventory: ## Generate inventory from environment variables
	@echo "$(BLUE)Generating inventory from environment...$(NC)"
	@./generate-inventory.sh
	@echo "$(GREEN)Inventory generated!$(NC)"

edit-config: ## Edit VM configuration file
	@$${EDITOR:-vim} vars/vm_config.yml

edit-inventory: ## Edit Proxmox inventory
	@$${EDITOR:-vim} $(INVENTORY)

edit-vm-inventory: ## Edit VM inventory (for configure step)
	@$${EDITOR:-vim} $(VM_INVENTORY)

edit-env: ## Edit environment variables file
	@$${EDITOR:-vim} .env

##@ Testing & Validation

test-connection: check-env ## Test connection to Proxmox host
	@echo "$(BLUE)Testing connection to Proxmox host...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) proxmox_host -m ping $(ANSIBLE_OPTS)
	@echo "$(GREEN)Connection successful!$(NC)"

test-vm-connection: check-env ## Test connection to deployed VMs
	@echo "$(BLUE)Testing connection to VMs...$(NC)"
	@$(ANSIBLE) -i $(VM_INVENTORY) ceph_nodes -m ping $(ANSIBLE_OPTS)
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

deploy-only:
	@echo "$(BLUE)Deploying VMs to Proxmox...$(NC)"
	@$(ANSIBLE) -i $(INVENTORY) $(DEPLOY_PLAYBOOK) $(ANSIBLE_OPTS)

configure-only:
	@echo "$(BLUE)Configuring deployed VMs...$(NC)"
	@$(ANSIBLE) -i $(VM_INVENTORY) $(CONFIGURE_PLAYBOOK) $(ANSIBLE_OPTS)
