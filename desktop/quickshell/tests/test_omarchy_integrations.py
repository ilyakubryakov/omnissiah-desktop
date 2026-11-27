import importlib.machinery
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
def load(name, path):
    spec = importlib.util.spec_from_loader(name, importlib.machinery.SourceFileLoader(name, str(path)))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module
desktop = load('desktop', ROOT / 'bin/oninix-desktop')

@unittest.skipUnless(hasattr(desktop.notes, "update_marker"), "requires the ported desktop backend")
class NetworkIntegrationTests(unittest.TestCase):
    def test_network_uses_lowest_metric_physical_default_and_paired_counters(self):
        def connection(iface, kind, gateway):
            return '\n'.join([
                f'GENERAL.DEVICE:{iface}', f'GENERAL.TYPE:{kind}', 'GENERAL.STATE:100 (connected)',
                r'GENERAL.CONNECTION:Lab\: connection', f'GENERAL.CON-UUID:{iface}-id',
                f'IP4.GATEWAY:{gateway}', r'IP6.DNS[1]:2606\:4700\:4700\:\:1111',
            ])

        def execute(args, **kwargs):
            if args[:2] == ['nmcli', '-t'] and args[-1] == 'show':
                return '\n'.join([connection('eth0', 'ethernet', '192.0.2.1'),
                                  connection('wifi0', 'wifi', '198.51.100.1'),
                                  connection('tailscale0', 'tun', '')]).encode()
            if '-4' in args:
                return json.dumps([
                    {'dev': 'tailscale0', 'metric': 1},
                    {'dev': 'wifi0', 'metric': 10, 'gateway': '198.51.100.9'},
                    {'dev': 'eth0', 'metric': 100},
                ]).encode()
            return b'full'

        def read_counter(path):
            return {('wifi0', 'rx_bytes'): '150', ('wifi0', 'tx_bytes'): '70'}.get((path.parts[-3], path.name), '30')

        with patch.object(desktop, 'run', side_effect=execute) as command, \
                patch.object(Path, 'read_text', autospec=True, side_effect=read_counter):
            data = desktop.network_state()
        self.assertEqual(command.call_count, 3)
        self.assertEqual(data['primary'], 'wifi0')
        self.assertEqual([link['device'] for link in data['links']], ['wifi0', 'eth0'])
        link = data['links'][0]
        self.assertEqual((link['received'], link['sent'], link['gateway']), (150, 70, '198.51.100.9'))
        self.assertEqual(link['name'], 'Lab: connection')
        self.assertEqual(link['dns'], ['2606:4700:4700::1111'])

    def test_network_falls_back_to_ipv6_and_reports_no_route(self):
        device = b'GENERAL.DEVICE:eth0\nGENERAL.TYPE:ethernet\nGENERAL.STATE:100 (connected)\nIP6.ADDRESS[1]:2001\\:db8\\:\\:2/64\n'
        old = b'[{"dev":"eth0","flags":["linkdown"]}]'
        ipv6 = b'[{"dev":"eth0","gateway":"fe80::1"}]'
        with patch.object(desktop, 'run', side_effect=[device, old, ipv6, b'full']), \
                patch.object(Path, 'read_text', side_effect=FileNotFoundError):
            result = desktop.network_state()
        self.assertEqual(result['primary'], 'eth0')
        self.assertEqual(result['links'][0]['address'], '2001:db8::2/64')
        self.assertEqual(result['links'][0]['gateway'], 'fe80::1')
        self.assertIsNone(result['links'][0]['received'])
        with patch.object(desktop, 'run', side_effect=[device, old, b'[]', b'none']), \
                patch.object(Path, 'read_text', side_effect=FileNotFoundError):
            self.assertEqual(desktop.network_state()['primary'], 'eth0')
