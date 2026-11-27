import ast
import re
import shutil
import subprocess
import sys
from pathlib import Path

STORE_REFERENCE = re.compile(rb'/nix/store/[0-9a-df-np-sv-z]{32}-[A-Za-z0-9+._?=-]+')


def references(path):
    if path.suffix == '.drv':
        _, inputs, sources, *_ = ast.literal_eval(path.read_text().removeprefix('Derive'))
        return set(map(Path, [name for name, _ in inputs] + sources))
    archive = subprocess.check_output(['nix-store', '--dump', path])
    return {ref for name in STORE_REFERENCE.findall(archive)
            if (ref := Path(name.decode())) != path and ref.exists()}


def main(root, staging):
    seen, pending = set(), [root]
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        deps = sorted(references(path))
        target = staging / path.name
        if path.is_dir() and not path.is_symlink():
            shutil.copytree(path, target, symlinks=True)
        else:
            shutil.copy2(path, target, follow_symlinks=False)
        print(path, '', len(deps), *deps, sep='\n')
        pending.extend(deps)


if __name__ == '__main__':
    main(*(Path(arg) for arg in sys.argv[1:]))
