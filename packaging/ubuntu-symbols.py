#!/usr/bin/env python3

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

HERE = Path(__file__).resolve().parent

def build():
    entry = next(x for x in json.loads((HERE / 'fedora/sources.json').read_text()) if x['name'] == 'symbols-nerd-font')
    cache = Path.home() / '.cache/omnissiah/packages'
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / 'symbols.tar.xz'
    if not archive.exists():
        with urllib.request.urlopen(entry['url'], timeout=60) as response:
            archive.write_bytes(response.read(16 * 1024 * 1024))
    if hashlib.sha256(archive.read_bytes()).hexdigest() != entry['sha256']:
        raise ValueError('Nerd Fonts source checksum mismatch')
    output = cache / ('omnissiah-symbols-fonts_' + entry['version'] + '-2_all.deb')
    with tempfile.TemporaryDirectory(dir=cache) as work:
        root = Path(work)
        source, package = root / 'source', root / 'package'
        source.mkdir()
        with tarfile.open(archive) as tar: tar.extractall(source, filter='data')
        fonts = package / 'usr/share/fonts/truetype/omnissiah-symbols'
        fonts.mkdir(parents=True)
        for file in source.glob('*.ttf'): shutil.copy2(file, fonts / file.name)
        license_dir = package / 'usr/share/doc/omnissiah-symbols-fonts'
        license_dir.mkdir(parents=True)
        for file in source.glob('*'):
            if file.is_file() and 'license' in file.name.lower(): shutil.copy2(file, license_dir / file.name)
        if not list(fonts.glob('*.ttf')) or not list(license_dir.iterdir()):
            raise ValueError('Upstream archive lacks fonts or licenses')
        (package / 'DEBIAN').mkdir(mode=0o755)
        (package / 'DEBIAN/control').write_text('Package: omnissiah-symbols-fonts\nVersion: ' + entry['version'] + '-2\nArchitecture: all\nMaintainer: Omnissiah Desktop contributors\nDepends: fontconfig\nProvides: fonts-nerd-symbols\nConflicts: fonts-nerd-symbols\nReplaces: fonts-nerd-symbols\nSection: fonts\nPriority: optional\nDescription: Complete Nerd Symbols font for Omnissiah panels\n')

        for path in package.rglob('*'):
            path.chmod(0o755 if path.is_dir() else 0o644)
        subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(package), str(output)], check=True,
                       env={**os.environ, 'SOURCE_DATE_EPOCH': '1793577600'})
    return output

if __name__ == '__main__': print(build())
