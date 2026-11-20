"""Local AI and libvirt controls for the Xeneon Compute page."""
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET

SERVICES = {'ollama': 'Ollama', 'open-webui': 'Open WebUI', 'comfyui': 'ComfyUI'}
URI = 'qemu:///system'


def run(args, timeout=15):
    return subprocess.run(args, check=True, capture_output=True, timeout=timeout,
                          env={**os.environ, 'LC_ALL': 'C'}).stdout.decode()


def virsh(*args):
    return run(['virsh', '--connect', URI, *args],
               timeout=60 if args and args[0] in {'shutdown', 'reboot'} else 15)


def guest(identifier):
    if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', identifier):
        raise ValueError('Invalid virtual machine identifier')
    return ET.fromstring(virsh('dumpxml', identifier, '--inactive'))


def status():
    result = {'ts': time.time(), 'services': [], 'vms': [], 'errors': []}
    for name, label in SERVICES.items():
        try:
            state = run(['systemctl', 'show', name + '.service', '--property=ActiveState', '--value']).strip()
            result['services'].append({'id': name, 'name': label, 'state': state})
        except (OSError, subprocess.SubprocessError):
            result['services'].append({'id': name, 'name': label, 'state': 'unavailable'})
    try:
        for uuid in virsh('list', '--all', '--uuid').split():
            xml = guest(uuid)
            result['vms'].append({'id': uuid, 'name': xml.findtext('name'),
                'state': virsh('domstate', uuid).strip(), 'vcpus': int(xml.findtext('vcpu', '0')),
                'rdp': any('microsoft.com/win' in node.get('id', '') for node in xml.iter()),
                'memoryGiB': round(int(xml.findtext('memory', '0')) / 1048576, 1)})
        result['vms'].sort(key=lambda vm: vm['name'])
    except (OSError, subprocess.SubprocessError, ET.ParseError, ValueError):
        result['errors'].append('Libvirt unavailable')
    disk = shutil.disk_usage('/var/lib/libvirt/images')
    result['diskFreeGiB'] = round(disk.free / 1073741824)
    return result


def action(kind, identifier, verb):
    if kind == 'ai':
        if identifier not in {*SERVICES, 'all'} or verb not in {'start', 'stop'}:
            raise ValueError('Unknown AI action')
        mode = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'oninix-desktop/mode.json'
        try:
            gaming = json.loads(mode.read_text()).get('name') == 'game'
        except (OSError, ValueError):
            gaming = False
        if verb == 'start' and gaming:
            raise ValueError('Turn off Gaming mode before starting AI')
        units = [name + '.service' for name in SERVICES] if identifier == 'all' else [identifier + '.service']
        run(['systemctl', verb, *units], timeout=120)
    elif kind == 'vm':
        guest(identifier)  # Resolve only existing UUIDs, never shell text or virsh options.
        if verb not in {'start', 'shutdown', 'reboot', 'suspend', 'resume', 'console', 'rdp', 'vnc'}:
            raise ValueError('Unknown virtual machine action')
        if verb in {'rdp', 'vnc'}:
            subprocess.Popen([str(Path.home() / '.local/bin/oninix-remote'), verb, identifier],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True)
        elif verb == 'console':
            subprocess.Popen(['virt-viewer', '--connect', URI, '--full-screen', '--wait', identifier],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True)
        else:
            virsh(verb, identifier)
    else:
        raise ValueError('Unknown compute action')
    return {'ok': True}
