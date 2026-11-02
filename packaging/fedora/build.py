#!/usr/bin/env python3

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.request

HERE = Path(__file__).resolve().parent
BUILD_REQUIRES = ['rpm-build', 'gcc-c++', 'cmake', 'ninja-build', 'pkgconf-pkg-config',
                  'hyprutils-devel', 'hyprlang-devel', 'hyprwayland-scanner-devel',
                  'hyprland-protocols-devel', 'wayland-devel', 'wayland-protocols-devel', 'sdbus-cpp-devel',
                  'systemd-devel', 'python3-devel', 'python3-setuptools',
                  'python3-wheel', 'python3-hatchling', 'python3-hatch-vcs', 'pyproject-rpm-macros']

def spec(entry):
    name, ver = entry['name'], entry['version']
    if name in ('x-wr-timezone', 'recurring-ical-events', 'icalendar', 'tzdata'):
        module = name.replace('-', '_')
        license_id = {'icalendar': 'BSD-2-Clause', 'tzdata': 'Apache-2.0'}.get(name, 'GPL-3.0-or-later')
        common = f'''Name: python3-{name}
Version: {ver}
Release: 100.omnissiah%{{?dist}}
Summary: Calendar recurrence dependency for Omnissiah Desktop
License: {license_id}
URL: https://pypi.org/project/{name}/
Source0: {name}-{ver}.tar.gz
BuildArch: noarch
BuildRequires: python3-devel python3-setuptools python3-wheel python3-hatchling python3-hatch-vcs pyproject-rpm-macros
%description
Upstream Python library, packaged without a separate Python environment.
%prep
%autosetup -n {module}-{ver}
'''
        if name == 'x-wr-timezone':

            common += "sed -i 's/from setuptools.command.test import test as TestCommandBase/from setuptools.command.build_py import build_py as TestCommandBase/' setup.py\n"
        return common + f'''%build
%pyproject_wheel
%install
%pyproject_install
%pyproject_save_files {module}
%files -f %{{pyproject_files}}
''' + ('%{_bindir}/' + name + '\n' if name in ('x-wr-timezone', 'icalendar') else '')
    if name == 'hypridle':
        return f'''Name: hypridle
Version: {ver}
Release: 1.omnissiah%{{?dist}}
Summary: Idle daemon for Hyprland
License: BSD-3-Clause
URL: https://github.com/hyprwm/hypridle
Source0: hypridle-{ver}.tar.gz
BuildRequires: gcc-c++ cmake ninja-build pkgconf-pkg-config hyprutils-devel hyprlang-devel hyprwayland-scanner-devel hyprland-protocols-devel wayland-devel wayland-protocols-devel sdbus-cpp-devel systemd-devel
%description
Native build of the upstream Hyprland idle daemon.
%prep
%autosetup
%build
%cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
%cmake_build -j2
%install
%cmake_install
%files
%license LICENSE
%{{_bindir}}/hypridle
%{{_datadir}}/hypr*
%{{_userunitdir}}/hypridle.service
'''
    return f'''Name: omnissiah-symbols-fonts
Version: {ver}
Release: 1.omnissiah%{{?dist}}
Summary: Nerd Fonts symbols for Omnissiah panels
License: MIT
URL: https://github.com/ryanoasis/nerd-fonts
Source0: symbols-nerd-font-{ver}.tar.xz
BuildArch: noarch
Requires: fontconfig
%description
Unmodified Symbols Nerd Font. Other fonts are supplied by Fedora.
%prep
%setup -q -c
%install
mkdir -p %{{buildroot}}%{{_datadir}}/fonts/omnissiah-symbols
cp *.ttf %{{buildroot}}%{{_datadir}}/fonts/omnissiah-symbols/
%files
%license LICENSE*
%{{_datadir}}/fonts/omnissiah-symbols
'''

def main():
    if '--dependencies' in sys.argv:
        print(' '.join(BUILD_REQUIRES)); return
    top = (Path.home() / '.cache/omnissiah/rpmbuild').resolve()
    for folder in ('SOURCES', 'SPECS', 'RPMS', 'SRPMS', 'BUILD', 'BUILDROOT'):
        (top / folder).mkdir(parents=True, exist_ok=True)
    for stale in (top / 'RPMS').glob('*/*.rpm'):
        stale.unlink()
    for entry in json.loads((HERE / 'sources.json').read_text()):
        suffix = '.tar.xz' if entry['name'] == 'symbols-nerd-font' else '.tar.gz'
        archive = top / 'SOURCES' / (entry['name'] + '-' + entry['version'] + suffix)
        if not archive.exists():
            with urllib.request.urlopen(entry['url'], timeout=60) as response:
                payload = response.read(64 * 1024 * 1024 + 1)
            if len(payload) > 64 * 1024 * 1024: raise ValueError('Source archive exceeds size limit')
            archive.write_bytes(payload)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('Source checksum mismatch: ' + entry['name'])
        recipe = top / 'SPECS' / (entry['name'] + '.spec')
        recipe.write_text(spec(entry))
        subprocess.run(['rpmbuild', '-ba', '--define', '_topdir ' + str(top), str(recipe)], check=True)
    print('Built native packages under ' + str(top / 'RPMS'))

if __name__ == '__main__': main()
