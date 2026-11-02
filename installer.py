#!/usr/bin/env python3

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent
SUPPORTED = ('arch', 'cachyos', 'ubuntu', 'fedora')
THEMED = ['.config/gtk-3.0', '.config/gtk-4.0', '.config/qt5ct', '.config/qt6ct',
          '.config/kdeglobals', '.config/starship.toml', '.config/MangoHud/MangoHud.conf',
          '.config/REAPER/libSwell-user.colortheme', '.config/btop/themes/kanagawa.theme',
          *[f'.local/share/color-schemes/Station-{p}.colors' for p in ('graphite','omnissiah','kanagawa-dragon','kanagawa-lotus','tesla-day','tesla-night')]]

def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)

def version(value):
    match = re.search(r'(\d+)\.(\d+)(?:\.(\d+))?', value)
    if not match:
        raise ValueError('Cannot determine version: ' + value[:100])
    return tuple(int(x or 0) for x in match.groups())

def distro(override=None):
    if override:
        return override
    if platform.system() != 'Linux':
        raise ValueError('Unsupported OS. Omnissiah Desktop supports Arch, CachyOS, Ubuntu and Fedora.')
    data = platform.freedesktop_os_release()
    name = data.get('ID', '')
    if name not in SUPPORTED:
        raise ValueError('Unsupported distribution: ' + name + '. Supported: ' + ', '.join(SUPPORTED))
    spec = manifest(name)
    if spec.get('minimum') and version(data.get('VERSION_ID', '0') + '.0') < version(spec['minimum'] + '.0'):
        raise ValueError(name + ' ' + spec['minimum'] + '+ is required for native desktop packages.')
    return name

def manifest(name):
    return json.loads((ROOT / 'packages.json').read_text())['arch' if name == 'cachyos' else name]

def commands(name):

    packages = [p for p in manifest(name)['packages'] if not (name in ('arch', 'cachyos') and p == 'python-msal')]
    if name in ('arch', 'cachyos'):

        return [['sudo', 'pacman', '-Syu', '--needed', *packages]]
    if name == 'ubuntu':
        return [['sudo', 'apt-get', 'update'], ['sudo', 'apt-get', 'install', *packages]]
    return [['sudo', 'dnf', 'install', *packages]]

def native_extras(name, enable_copr=False):

    if name in ('arch', 'cachyos'):
        if subprocess.run(['pacman', '-Q', 'python-msal'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            return
        run(['sudo', 'pacman', '-Syu', '--needed', 'base-devel', 'python-build', 'python-installer',
             'python-setuptools', 'python-wheel', 'python-requests', 'python-cryptography', 'python-pyjwt'])
        target = Path.home() / '.cache/omnissiah/packages/msal'
        target.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'packaging/arch/PKGBUILD', target / 'PKGBUILD')
        run(['makepkg', '--syncdeps', '--install', '--needed'], cwd=target)
    elif name == 'ubuntu':
        run([sys.executable, ROOT / 'packaging/ubuntu-symbols.py'])
        deb = sorted((Path.home() / '.cache/omnissiah/packages').glob('omnissiah-symbols-fonts_*_all.deb'))[-1]
        run(['sudo', 'apt-get', 'install', str(deb)])
    elif name == 'fedora':
        if not enable_copr:
            raise ValueError('Fedora needs native COPR packages. Review the package sources in README.md, then use --fedora-copr to opt in.')
        run(['sudo', 'dnf', 'install', 'dnf5-plugins'])
        for repo in ('giperborey/Hyprland', 'errornointernet/quickshell'):
            run(['sudo', 'dnf', 'copr', 'enable', repo])
        sys.path.insert(0, str(ROOT / 'packaging/fedora'))
        import build as rpm_build
        run(['sudo', 'dnf', 'install', *rpm_build.BUILD_REQUIRES])
        run([sys.executable, ROOT / 'packaging/fedora/build.py'])
        rpms = sorted((Path.home() / '.cache/omnissiah/rpmbuild/RPMS').glob('*/*.rpm'))
        run(['sudo', 'dnf', 'install', *[p for p in rpms if 'debuginfo' not in p.name and 'debugsource' not in p.name]])

def doctor():
    issues = []
    for binary in ('Hyprland', 'quickshell', 'uwsm', 'hyprlock', 'hypridle', 'hyprpaper',
                   'mako', 'rofi', 'kitty', 'wl-copy', 'wl-paste', 'cliphist', 'grim', 'slurp',
                   'jq', 'curl', 'wpctl', 'pw-dump', 'nmcli', 'qt6ct', 'gsettings', 'kwriteconfig6',
                   'wf-recorder', 'pactl', 'hyprpicker', 'tesseract', 'zbarimg'):
        if not shutil.which(binary):
            issues.append('Missing executable: ' + binary)
    for binary, minimum in [('Hyprland', (0, 55, 0)), ('quickshell', (0, 3, 0))]:
        if shutil.which(binary):
            with tempfile.TemporaryDirectory(prefix='omnissiah-probe-') as runtime:
                result = run([binary, '--version'], capture_output=True, text=True, env={**os.environ, 'XDG_RUNTIME_DIR': os.environ.get('XDG_RUNTIME_DIR', runtime)})
            if version(result.stdout + result.stderr) < minimum:
                issues.append(binary + ' must be >= ' + '.'.join(map(str, minimum)))
    if sys.version_info < (3, 11):
        issues.append('Python 3.11+ is required')
    for module in ('icalendar', 'recurring_ical_events', 'dateutil', 'msal', 'google_auth_oauthlib', 'PIL', 'babel'):
        import importlib.util
        if importlib.util.find_spec(module) is None:
            issues.append('Missing Python module: ' + module)
    if issues:
        raise ValueError('\n'.join(issues) + '\nNo configuration has been changed.')

def lexists(path):
    return path.exists() or path.is_symlink()

def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.chmod(0o600)
    temp.replace(path)

def desktop_settings():
    values = {}
    if not shutil.which('gsettings'):
        return values
    for key in ('font-name', 'monospace-font-name', 'gtk-theme', 'icon-theme', 'color-scheme'):
        result = subprocess.run(['gsettings', 'get', 'org.gnome.desktop.interface', key], capture_output=True, text=True)
        if result.returncode == 0:
            values[key] = result.stdout.strip()
    return values

def links(release):
    result = {'.config/hypr': 'config/hypr', '.config/quickshell': 'quickshell',
              '.config/mako': 'config/mako', '.config/fuzzel': 'config/fuzzel',
              '.config/rofi/station.rasi': 'dotfiles/.config/rofi/station.rasi',
              '.config/swappy/config': 'dotfiles/.config/swappy/config',
              '.config/kitty/kitty.conf': 'config/kitty.conf',
              '.config/fontconfig/conf.d/90-omnissiah.conf': 'config/fonts.conf',
              '.config/uwsm/env-hyprland': 'config/uwsm-env'}
    for file in (release / 'dotfiles/.local/bin').iterdir():
        if file.is_file():
            result['.local/bin/' + file.name] = 'dotfiles/.local/bin/' + file.name
    for file in (release / 'systemd/user').iterdir():
        result['.config/systemd/user/' + file.name] = 'systemd/user/' + file.name
    return result

def release_files():
    for path in sorted(ROOT.rglob('*')):
        rel = path.relative_to(ROOT)
        if any(p in {'.git', '__pycache__', '.venv', 'artifacts', 'out', '.cache'} for p in rel.parts):
            continue
        if path.is_symlink():
            raise ValueError('Source tree must not contain symlinks: ' + str(rel))
        if path.is_file() and path.suffix != '.pyc' and path.name != '.DS_Store':
            yield path, rel

def deploy(home, state, data):
    entries = list(release_files())
    digest = hashlib.sha256()
    for path, rel in entries:
        digest.update(str(rel).encode() + b'\0' + path.read_bytes())
    release = data / 'releases' / digest.hexdigest()[:16]
    receipt_path = state / 'receipt.json'
    receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else None
    if not release.exists():
        staging = release.with_name(release.name + '.tmp')
        if staging.exists(): shutil.rmtree(staging)
        for path, rel in entries:
            target = staging / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        staging.rename(release)
    current = data / 'current'
    linkmap = links(release)

    if receipt:
        for relative, source in linkmap.items():
            destination = home / relative
            if lexists(destination) and not (destination.is_symlink() and os.readlink(destination) == str(data / 'current' / source)):
                raise ValueError('Managed path was replaced locally: ' + str(destination))
    if receipt and receipt.get('release') == str(release):
        print('This release is already installed; preferences were kept.')
        return
    backup = state / 'backups' / time.strftime('%Y%m%d-%H%M%S')
    backup.mkdir(parents=True, exist_ok=True)
    receipt = receipt or {'backup': str(backup), 'paths': [], 'releases': [], 'desktop_settings': desktop_settings()}

    for relative in list(linkmap) + THEMED:
        if relative in receipt['paths']:
            continue
        destination = home / relative
        original = Path(receipt['backup']) / relative
        if lexists(destination):
            original.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(destination, original, symlinks=True) if destination.is_dir() and not destination.is_symlink() else shutil.copy2(destination, original, follow_symlinks=False)
        receipt['paths'].append(relative)
        atomic_json(receipt_path, receipt)
        if relative in linkmap and lexists(destination):
            if destination.is_dir() and not destination.is_symlink(): shutil.rmtree(destination)
            else: destination.unlink()
    temporary = data / 'current.new'
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(release)
    temporary.replace(current)
    for relative, source in linkmap.items():
        destination = home / relative
        target = current / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink() and os.readlink(destination) == str(target): continue
        if lexists(destination):
            raise ValueError('A managed path was replaced locally. Preserve it before updating: ' + str(destination))
        destination.symlink_to(target)
    config = home / '.config/omnissiah'
    config.mkdir(parents=True, exist_ok=True)
    for name, content in [('integrations.json', '{}\n'), ('monitors.conf', ''), ('local.lua', '')]:
        target = config / name
        if not target.exists(): target.write_text(content)
    receipt['release'] = str(release)
    receipt['releases'].append(str(release))
    atomic_json(receipt_path, receipt)
    print('Installed release ' + release.name + '. Backup: ' + receipt['backup'])

def restore(home, state):
    receipt_path = state / 'receipt.json'
    if not receipt_path.exists():
        raise ValueError('No installation receipt found.')
    receipt = json.loads(receipt_path.read_text())
    archive = state / 'removed' / time.strftime('%Y%m%d-%H%M%S')
    for relative in receipt['paths']:
        current, original = home / relative, Path(receipt['backup']) / relative
        if lexists(current):
            saved = archive / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(current), saved)
        if lexists(original):
            current.parent.mkdir(parents=True, exist_ok=True)
            if original.is_dir() and not original.is_symlink(): shutil.copytree(original, current, symlinks=True)
            else: shutil.copy2(original, current, follow_symlinks=False)
    if receipt.get('desktop_settings') and shutil.which('gsettings'):
        atomic_json(archive / 'desktop-settings-before-restore.json', desktop_settings())
        for key, value in receipt['desktop_settings'].items():
            result = subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', key, value], capture_output=True)
            if result.returncode:
                print('Could not restore desktop setting: ' + key + '. Its saved value remains in last-removed.json.')
    receipt_path.rename(state / 'last-removed.json')
    print('Previous configuration restored. Later edits preserved in ' + str(archive))
    print('Preferences, notes, calendars and native packages were kept.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'plan', 'doctor', 'uninstall'], nargs='?', default='install')
    parser.add_argument('--distro', choices=SUPPORTED, help='plan only; installation uses /etc/os-release')
    parser.add_argument('--no-packages', action='store_true', help='use already installed native packages (still checked)')
    parser.add_argument('--fedora-copr', action='store_true', help='explicitly enable the documented Fedora COPRs and build missing native RPMs')
    args = parser.parse_args()
    if args.distro and args.action != 'plan': parser.error('--distro is only allowed for plan')
    name = distro(args.distro)
    if args.action == 'plan':
        extras = {'arch': 'Build and install the pinned python-msal PKGBUILD with makepkg.',
                  'cachyos': 'Build and install the pinned python-msal PKGBUILD with makepkg.',
                  'ubuntu': 'Package and install the complete Nerd Symbols font as a native .deb.',
                  'fedora': 'With --fedora-copr: enable giperborey/Hyprland and errornointernet/quickshell; build missing dependencies as native RPMs.'}
        print(json.dumps({'distro': name, 'before_commands': extras[name], 'commands': commands(name), 'runtime': {'Hyprland': '>=0.55', 'quickshell': '>=0.3'},
                          'configuration': 'backed up before replacement', 'login': 'select Hyprland (uwsm)'}, indent=2))
        return
    if os.geteuid() == 0: raise ValueError('Run as your desktop user, not root. Only package installation uses sudo.')
    if args.action == 'doctor': doctor(); print('Runtime requirements satisfied.'); return
    home = Path.home()
    for variable, suffix in [('XDG_CONFIG_HOME', '.config'), ('XDG_STATE_HOME', '.local/state'), ('XDG_DATA_HOME', '.local/share')]:
        if os.environ.get(variable) and Path(os.environ[variable]) != home / suffix:
            raise ValueError('This preview requires standard XDG paths: ' + variable)
    state, data = home / '.local/state/omnissiah', home / '.local/share/omnissiah'
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / 'install.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == 'uninstall': restore(home, state); return
        if not args.no_packages:
            native_extras(name, args.fedora_copr)
            for command in commands(name): run(command)
        doctor()
        deploy(home, state, data)
        run([home / '.local/bin/theme'])
        run(['systemctl', '--user', 'daemon-reload'])
    print('Ready. Log out and choose Hyprland (uwsm), or run uwsm start Hyprland from a TTY.')

if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print('Omnissiah: ' + str(error), file=sys.stderr)
        sys.exit(1)
