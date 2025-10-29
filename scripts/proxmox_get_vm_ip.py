#!/usr/bin/env python3
"""
Get VM IP address from Proxmox via API
"""

import sys
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


def get_vm_ip(host, user, password, node, vmid, debug=False):
    """Get first non-loopback IPv4 address from VM guest agent"""
    base_url = f"https://{host}:8006/api2/json"

    # Authenticate
    auth_url = f"{base_url}/access/ticket"
    auth_data = {'username': user, 'password': password}

    try:
        response = requests.post(auth_url, data=auth_data, verify=False, timeout=5)
        response.raise_for_status()
        auth_result = response.json()['data']
        ticket = auth_result['ticket']
        csrf_token = auth_result['CSRFPreventionToken']
    except Exception as e:
        if debug:
            print(f"Authentication failed: {e}", file=sys.stderr)
        return None

    # Get network interfaces from guest agent
    interfaces_url = f"{base_url}/nodes/{node}/qemu/{vmid}/agent/network-get-interfaces"
    headers = {'CSRFPreventionToken': csrf_token}
    cookies = {'PVEAuthCookie': ticket}

    try:
        response = requests.get(
            interfaces_url,
            headers=headers,
            cookies=cookies,
            verify=False,
            timeout=5
        )
        response.raise_for_status()
        interfaces = response.json()['data']['result']

        # Find first non-loopback IPv4 address
        for iface in interfaces:
            if 'ip-addresses' in iface:
                for addr in iface['ip-addresses']:
                    ip = addr.get('ip-address', '')
                    if ip and not ip.startswith('127.') and ':' not in ip:
                        return ip
    except Exception as e:
        if debug:
            print(f"Failed to get network interfaces: {e}", file=sys.stderr)
            print(f"URL: {interfaces_url}", file=sys.stderr)
        return None

    return None


if __name__ == '__main__':
    if len(sys.argv) < 6:
        print("Usage: proxmox_get_vm_ip.py <host> <user> <password> <node> <vmid> [--debug]", file=sys.stderr)
        sys.exit(1)

    host = sys.argv[1]
    user = sys.argv[2]
    password = sys.argv[3]
    node = sys.argv[4]
    vmid = sys.argv[5]
    debug = len(sys.argv) > 6 and sys.argv[6] == '--debug'

    ip = get_vm_ip(host, user, password, node, vmid, debug=debug)
    if ip:
        print(ip)
        sys.exit(0)
    else:
        if debug:
            print("No IP address found", file=sys.stderr)
        sys.exit(1)
