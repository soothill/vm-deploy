#!/usr/bin/python3
# -*- coding: utf-8 -*-

# Copyright: (c) 2025, Darren Soothill
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: proxmox_api
short_description: Manage Proxmox VMs via API
version_added: "1.0.0"
description:
    - Create, configure, start, stop, and delete Proxmox VMs using the Proxmox API
    - Replaces qm CLI commands with native API calls
options:
    api_host:
        description: Proxmox API host
        required: true
        type: str
    api_user:
        description: Proxmox API user (e.g. root@pam)
        required: true
        type: str
    api_password:
        description: Proxmox API password
        required: true
        type: str
    node:
        description: Proxmox node name
        required: true
        type: str
    vmid:
        description: VM ID
        required: true
        type: int
    state:
        description: Desired state of the VM
        choices: ['present', 'absent', 'started', 'stopped', 'current']
        default: 'present'
        type: str
    name:
        description: VM name
        type: str
    memory:
        description: Memory in MB
        type: int
    cores:
        description: Number of CPU cores
        type: int
    sockets:
        description: Number of CPU sockets
        type: int
    config:
        description: Additional VM configuration as dict
        type: dict
'''

EXAMPLES = r'''
- name: Create a VM
  proxmox_api:
    api_host: proxmox.local
    api_user: root@pam
    api_password: password
    node: pve
    vmid: 100
    state: present
    name: test-vm
    memory: 2048
    cores: 2

- name: Start a VM
  proxmox_api:
    api_host: proxmox.local
    api_user: root@pam
    api_password: password
    node: pve
    vmid: 100
    state: started

- name: Delete a VM
  proxmox_api:
    api_host: proxmox.local
    api_user: root@pam
    api_password: password
    node: pve
    vmid: 100
    state: absent
'''

RETURN = r'''
vmid:
    description: VM ID
    type: int
    returned: always
status:
    description: Current VM status
    type: str
    returned: when state is current
'''

from ansible.module_utils.basic import AnsibleModule
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


class ProxmoxAPI:
    def __init__(self, host, user, password, node, verify_ssl=False):
        self.host = host
        self.user = user
        self.password = password
        self.node = node
        self.verify_ssl = verify_ssl
        self.base_url = f"https://{host}:8006/api2/json"
        self.ticket = None
        self.csrf_token = None

    def authenticate(self):
        """Get authentication ticket and CSRF token"""
        url = f"{self.base_url}/access/ticket"
        data = {
            'username': self.user,
            'password': self.password
        }
        response = requests.post(url, data=data, verify=self.verify_ssl)
        response.raise_for_status()
        result = response.json()['data']
        self.ticket = result['ticket']
        self.csrf_token = result['CSRFPreventionToken']

    def _get_headers(self):
        """Get headers with authentication"""
        return {
            'CSRFPreventionToken': self.csrf_token
        }

    def _get_cookies(self):
        """Get cookies with authentication ticket"""
        return {
            'PVEAuthCookie': self.ticket
        }

    def vm_exists(self, vmid):
        """Check if VM exists"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}/status/current"
        try:
            response = requests.get(
                url,
                headers=self._get_headers(),
                cookies=self._get_cookies(),
                verify=self.verify_ssl
            )
            return response.status_code == 200
        except:
            return False

    def get_vm_status(self, vmid):
        """Get VM status"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}/status/current"
        response = requests.get(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()['data']

    def create_vm(self, vmid, name=None, memory=None, cores=None, sockets=None, **kwargs):
        """Create a new VM"""
        url = f"{self.base_url}/nodes/{self.node}/qemu"
        data = {'vmid': vmid}

        if name:
            data['name'] = name
        if memory:
            data['memory'] = memory
        if cores:
            data['cores'] = cores
        if sockets:
            data['sockets'] = sockets

        # Add any additional config
        data.update(kwargs)

        response = requests.post(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            data=data,
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()

    def configure_vm(self, vmid, **kwargs):
        """Configure VM settings"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}/config"
        response = requests.put(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            data=kwargs,
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()

    def start_vm(self, vmid):
        """Start a VM"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}/status/start"
        response = requests.post(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()

    def stop_vm(self, vmid):
        """Stop a VM"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}/status/stop"
        response = requests.post(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()

    def delete_vm(self, vmid, purge=True):
        """Delete a VM"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}"
        params = {}
        if purge:
            params['purge'] = 1
        response = requests.delete(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            params=params,
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()

    def get_guest_network_interfaces(self, vmid):
        """Get network interfaces from guest agent"""
        url = f"{self.base_url}/nodes/{self.node}/qemu/{vmid}/agent/network-get-interfaces"
        response = requests.get(
            url,
            headers=self._get_headers(),
            cookies=self._get_cookies(),
            verify=self.verify_ssl
        )
        response.raise_for_status()
        return response.json()['data']['result']


def run_module():
    module_args = dict(
        api_host=dict(type='str', required=True),
        api_user=dict(type='str', required=True),
        api_password=dict(type='str', required=True, no_log=True),
        node=dict(type='str', required=True),
        vmid=dict(type='int', required=True),
        state=dict(type='str', default='present', choices=['present', 'absent', 'started', 'stopped', 'current']),
        name=dict(type='str', required=False),
        memory=dict(type='int', required=False),
        cores=dict(type='int', required=False),
        sockets=dict(type='int', required=False),
        config=dict(type='dict', required=False, default={})
    )

    result = dict(
        changed=False,
        vmid=0,
        status=''
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    # Initialize API client
    api = ProxmoxAPI(
        module.params['api_host'],
        module.params['api_user'],
        module.params['api_password'],
        module.params['node']
    )

    try:
        api.authenticate()
    except Exception as e:
        module.fail_json(msg=f"Authentication failed: {str(e)}", **result)

    vmid = module.params['vmid']
    state = module.params['state']
    result['vmid'] = vmid

    try:
        vm_exists = api.vm_exists(vmid)

        if state == 'current':
            # Just return current status
            if vm_exists:
                status = api.get_vm_status(vmid)
                result['status'] = status['status']
            else:
                result['status'] = 'absent'
            module.exit_json(**result)

        elif state == 'present':
            if not vm_exists:
                if module.check_mode:
                    result['changed'] = True
                    module.exit_json(**result)

                # Create VM
                create_params = {}
                if module.params['name']:
                    create_params['name'] = module.params['name']
                if module.params['memory']:
                    create_params['memory'] = module.params['memory']
                if module.params['cores']:
                    create_params['cores'] = module.params['cores']
                if module.params['sockets']:
                    create_params['sockets'] = module.params['sockets']

                create_params.update(module.params['config'])
                api.create_vm(vmid, **create_params)
                result['changed'] = True

        elif state == 'absent':
            if vm_exists:
                if module.check_mode:
                    result['changed'] = True
                    module.exit_json(**result)

                api.delete_vm(vmid)
                result['changed'] = True

        elif state == 'started':
            if vm_exists:
                status = api.get_vm_status(vmid)
                if status['status'] != 'running':
                    if module.check_mode:
                        result['changed'] = True
                        module.exit_json(**result)

                    api.start_vm(vmid)
                    result['changed'] = True

        elif state == 'stopped':
            if vm_exists:
                status = api.get_vm_status(vmid)
                if status['status'] == 'running':
                    if module.check_mode:
                        result['changed'] = True
                        module.exit_json(**result)

                    api.stop_vm(vmid)
                    result['changed'] = True

        module.exit_json(**result)

    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()
