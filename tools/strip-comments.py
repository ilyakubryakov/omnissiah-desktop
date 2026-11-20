#!/usr/bin/env python3
import ast
import re
import sys
from pathlib import Path

KEEP = re.compile(r'^\s*(#!|//@|#\s*(shellcheck|noqa|type:|-\*-)|#\s*theme:|//\s*theme:|--\s*theme:|/\*\s*theme:|\.pragma)')
LINE = {
    '.lua': re.compile(r'^\s*--(?!\[\[)'),
    '.qml': re.compile(r'^\s*//'),
    '.js': re.compile(r'^\s*//'),
    '.cjs': re.compile(r'^\s*//'),
    '.nix': re.compile(r'^\s*#'),
    '.sh': re.compile(r'^\s*#'),
    '.py': re.compile(r'^\s*#'),
}

def kind(path):
    if path.suffix in LINE:
        return path.suffix
    try:
        first = path.read_text().split('\n', 1)[0]
    except (UnicodeDecodeError, OSError):
        return None
    if first.startswith('#!') and 'python' in first:
        return '.py'
    if first.startswith('#!') and ('sh' in first.split('/')[-1] or 'bash' in first):
        return '.sh'
    return None

def docstring_lines(text):
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return set()
    lines = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) and node.body:
            first = node.body[0]
            if isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant) and isinstance(first.value.value, str):
                if len(node.body) == 1 and not isinstance(node, ast.Module):
                    continue
                lines.update(range(first.lineno, first.end_lineno + 1))
    return lines

def in_heredoc_or_string(kind_, lines):
    if kind_ not in ('.nix', '.sh'):
        return set()
    inside, skip, marker = False, set(), None
    for number, line in enumerate(lines, 1):
        if kind_ == '.nix':
            count = line.count("''") - line.count("'''") * 2
            if inside:
                skip.add(number)
            if count % 2 == 1:
                inside = not inside
        else:
            if marker:
                skip.add(number)
                if line.strip() == marker:
                    marker = None
                continue
            found = re.search(r"<<-?\s*'?\"?([A-Z_]+)'?\"?", line)
            if found:
                marker = found.group(1)
    return skip

def strip(path):
    kind_ = kind(path)
    if not kind_:
        return 0
    text = path.read_text()
    lines = text.split('\n')
    drop = docstring_lines(text) if kind_ == '.py' else set()
    protected = in_heredoc_or_string(kind_, lines)
    pattern = LINE[kind_]
    out, removed = [], 0
    for number, line in enumerate(lines, 1):
        if number in drop or (number not in protected and pattern.match(line) and not KEEP.match(line)):
            removed += 1
            continue
        out.append(line)
    cleaned = re.sub(r'\n{3,}', '\n\n', '\n'.join(out))
    if cleaned != text:
        path.write_text(cleaned)
    return removed

def main(paths):
    total = 0
    for name in paths:
        for path in ([Path(name)] if Path(name).is_file() else sorted(Path(name).rglob('*'))):
            if path.is_file() and '.git' not in path.parts and path.suffix not in ('.tpl', '.json', '.toml', '.md', '.png'):
                count = strip(path)
                if count:
                    print(f'{count:4d}  {path}')
                    total += count
    print(f'{total} comment lines removed')

if __name__ == '__main__':
    main(sys.argv[1:])
