import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SINGLETON = re.compile(r"^\s*pragma Singleton\s*$", re.MULTILINE)

class QmlSmokeTest(unittest.TestCase):
    def test_qml_parses_and_resolves_imports(self):
        lint, shell = shutil.which("qmllint"), shutil.which("quickshell")
        if not (lint and shell):
            self.skipTest("Qt and Quickshell type metadata required")
        imports = [Path(command).resolve().parents[1] / "lib/qt-6/qml" for command in (lint, shell)]
        if not (imports[0] / "QtQuick/qmldir").is_file() or not (imports[1] / "Quickshell/qmldir").is_file():
            self.skipTest("Qt and Quickshell type metadata required")
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "quickshell"
            shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns("assets", "tests"))
            files = sorted(source.rglob("*.qml"))
            for directory in {p.parent for p in files}:
                if (directory / "qmldir").exists():
                    continue
                lines = []
                for path in (p for p in files if p.parent == directory and p.name not in {"shell.qml"}):
                    kind = "singleton " if SINGLETON.search(path.read_text()) else ""
                    lines.append(f"{kind}{path.stem} {path.name}\n")
                (directory / "qmldir").write_text("".join(lines))
            command = [lint, "--silent", "--json", "-", "--import", "error", "--read-only-property", "error"]
            command += [arg for path in imports for arg in ("-I", str(path))]
            result = subprocess.run(command + list(map(str, files)), text=True, capture_output=True, timeout=40)
            report = json.loads(result.stdout)
            self.assertEqual(len(report["files"]), len(files))
            failures = [
                f"{Path(file['filename']).relative_to(source)}:{issue.get('line', '?')}: {issue['message']}"
                for file in report["files"] for issue in file["warnings"]
                if issue["type"] == "error" or issue["id"] == "syntax"
            ]
            self.assertEqual(failures, [])
            self.assertEqual(result.returncode, 0, result.stderr)

if __name__ == "__main__":
    unittest.main()
