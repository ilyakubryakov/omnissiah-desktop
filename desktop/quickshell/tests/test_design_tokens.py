from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
GENERATED_PALETTE = ROOT / "shared" / "PaletteDefaults.js"
COMMENTS_AND_STRINGS = re.compile(
    r"""//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"""
)
BINDING = re.compile(
    r"(?<![\w.])(?:(?P<color>property\s+color\s+\w+|\w*[Cc]olor|tint|badge|fillStyle|strokeStyle)"
    r"[ \t]*[:=](?!=)|(?P<name>[a-zA-Z_][\w.]*)\s*:)"
)
EXPRESSION_DELIMITER = re.compile(r"[()[\]{},;\n]")
LEADING_OPERATOR = re.compile(r"[?:.+*/%&|<>-]")
TRAILING_OPERATOR = re.compile(r"[?:.+*/%&|<>=-]$")
GEOMETRY = re.compile(r"(?:columns|cols|rows|count|\w+Count|rescaleSize|axis\.[xyz]|angle|rotation|rotationScale|depth|opacity|scale|z)")
GROUP = re.compile(r"(?<![\w.])(axis|border)\s*\{")
PX_CALL = re.compile(r"\bDesktopStyle\.px\s*\(")
PARENTHESIS = re.compile(r"[()]")
SIZE_LITERAL = re.compile(r"(?<![\w.])(?:\d+(?:\.\d+)?|\.\d+)(?![\w.])")
PALETTE_ROLE = re.compile(r"\b(Palette|Colors)\s*\.\s*(\w+)")
PROPERTY = re.compile(r"\bproperty\s+\w+\s+(\w+)\s*:")
NAMED_COLOR = re.compile(r"""(?:^|[?:]|\|\||\?\?|&&)\s*\(*\s*(["'])([a-zA-Z]+)\1(?=\s*\)*\s*(?:$|[:,]|\|\||\?\?))""")
HEX_COLOR = re.compile(r"""(["'])#(?:[a-fA-F0-9]{3}|[a-fA-F0-9]{6}|[a-fA-F0-9]{8})\1""")
CHANNEL = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)"
COLOR_CHANNELS = re.compile(rf"Qt\.(?:rgba|hsla|hsva)\(\s*(?:{CHANNEL}\s*,\s*){{3}}")
ROLE_FILES = {"Palette": ROOT / "shared" / "Palette.qml", "Colors": ROOT / "bar" / "Colors.qml"}
ROLES = {name: set(PROPERTY.findall(path.read_text())) for name, path in ROLE_FILES.items()}
FONT_ERROR = "use a DesktopStyle token for pixelSize"

def mask(source, *, strings=False):
    def replace(match):
        text = match[0]
        if text.startswith(("//", "/*")):
            return re.sub(r"[^\n]", " ", text)
        return re.sub(r"[^\n]", "@", text) if strings else text

    return COMMENTS_AND_STRINGS.sub(replace, source)

def expression_end(code, start, *, group=False):
    depth = 0
    for token in EXPRESSION_DELIMITER.finditer(code, start):
        char = token[0]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                return token.start()
            depth -= 1
            if depth == 0 and group:
                return token.end()
        elif depth == 0:
            if char == "\n":
                before = code[start:token.start()].rstrip()
                after = code[token.end():].lstrip()
                if not before or LEADING_OPERATOR.match(after) or TRAILING_OPERATOR.search(before):
                    continue
            return token.start()
    return len(code)

def px_calls(expression):
    cursor = 0
    while call := PX_CALL.search(expression, cursor):
        depth = 1
        for paren in PARENTHESIS.finditer(expression, call.end()):
            depth += 1 if paren[0] == "(" else -1
            if depth == 0:
                cursor = paren.end()
                yield call.start(), cursor, expression[call.end():paren.start()]
                break
        else:
            return

def token_violations(source, *, fixed_font=False):
    raw = mask(source)
    code = mask(raw, strings=True)
    for role in PALETTE_ROLE.finditer(code):
        singleton, name = role.groups()
        if name not in ROLES[singleton]:
            yield role.start(), f"unknown role {singleton}.{name}"

    groups = [
        (group[1], group.end(), expression_end(code, group.end() - 1, group=True))
        for group in GROUP.finditer(code)
    ]
    for binding in BINDING.finditer(code):
        name = binding["name"]
        if name in {"width", "x", "y", "z"}:
            for group, start, end in groups:
                if start <= binding.start() < end:
                    name = f"{group}.{name}"
                    break
        if binding["color"] or name in {"font.pixelSize", "pixelSize", "border.width"} or (name and GEOMETRY.fullmatch(name)):
            start = binding.end()
            end = expression_end(code, start)
            value = code[start:end]
            calls = list(px_calls(value))
            if name in {"font.pixelSize", "pixelSize"} and not fixed_font:
                for begin, finish, _ in reversed(calls):
                    value = value[:begin] + "token" + value[finish:]
                if SIZE_LITERAL.search(value):
                    yield binding.start(), FONT_ERROR
            elif name == "border.width" and any(re.fullmatch(r"\s*1(?:\.0+)?\s*", arg) for _, _, arg in calls):
                yield binding.start(), "keep 1 px borders independent of font size"
            elif name and GEOMETRY.fullmatch(name) and calls:
                yield binding.start(), f"keep {name} independent of font size"
            elif binding["color"] and any(match[2].lower() != "transparent" for match in NAMED_COLOR.finditer(raw[start:end])):
                yield binding.start(), "use a Palette role for named colors"
    for literal in (*HEX_COLOR.finditer(raw), *COLOR_CHANNELS.finditer(code)):
        yield literal.start(), "use a Palette role for RGB colors"

class DesignTokensTest(unittest.TestCase):
    def test_quickshell_uses_design_tokens(self):
        violations = []
        for path in sorted(ROOT.rglob("*")):
            if path.suffix not in {".qml", ".js"} or path == GENERATED_PALETTE:
                continue
            source = path.read_text()
            for offset, message in token_violations(source, fixed_font=False):
                line = source.count("\n", 0, offset) + 1
                violations.append(f"{path.relative_to(ROOT)}:{line}: {message}")
        self.assertEqual(violations, [])

    def test_panel_geometry_uses_logical_pixels(self):
        code = mask((ROOT / "bar" / "PanelStyle.qml").read_text(), strings=True)
        for name in ("barHeight", "widthPercent", "cornerRadius"):
            binding = re.search(rf"\b{name}\s*:", code)
            value = code[binding.end():expression_end(code, binding.end())]
            self.assertNotRegex(value, r"\bDesktopStyle\.(?!comfortable\b)\w+")
        side_gap = re.search(r"\bfunction sideGapFor\([^)]*\)\s*(\{)", code)
        start = side_gap.start(1)
        self.assertNotIn("DesktopStyle.", code[start:expression_end(code, start, group=True)])

    def test_detects_literal_values_in_bindings(self):
        for binding in (
            "font.pixelSize: 12", "font { pixelSize: 12 }",
            "font.pixelSize: compact ? 12 : Shared.DesktopStyle.fontSize",
            "font.pixelSize: Colors.fontSize + 2",
            "font.pixelSize: Math.max(\n    12, Colors.fontSize)",
            'color: "red"', '{ color: "orchid", value: 42 }', "color: pending\n    ? Palette.accent\n    : 'DarkGoldenRod'",
            'border.color: "#b8473a"', "color: Qt.rgba(1, 0, 0, alpha)",
        ):
            with self.subTest(binding=binding):
                self.assertTrue(list(token_violations(binding)))

    def test_detects_unknown_roles_and_scaled_geometry(self):
        for binding, message in (
            ("color: Palette.noSuchRole", "unknown role Palette.noSuchRole"),
            ("color: Bar.Colors.claudeBrand", "unknown role Colors.claudeBrand"),
            ("columns: Shared.DesktopStyle.px(7)", "keep columns"),
            ("rows: active\n ? 1\n : DesktopStyle.px(3)", "keep rows"),
            ("readonly property int count: Math.max(1,\n    DesktopStyle.px(12))", "keep count"),
            ("columnCount: wide ? DesktopStyle.px(3) : 2", "keep columnCount"),
            ("axis { x: DesktopStyle.px(1); y: 0 }", "keep axis.x"),
            ("rescaleSize: DesktopStyle.px(64)", "keep rescaleSize"),
            ("border.width: DesktopStyle.px(1)", "keep 1 px borders"),
            ("border { color: Palette.accent; width: DesktopStyle.px(\n 1.0) }", "keep 1 px borders"),
        ):
            with self.subTest(binding=binding):
                self.assertTrue(any(message in error for _, error in token_violations(binding)))

    def test_accepts_tokens_transparency_and_non_color_strings(self):
        code = """
            font.pixelSize: Shared.DesktopStyle.px(compact ? 12 : 15)
            font.pixelSize: Math.max(Bar.Colors.fontSize, Shared.DesktopStyle.px(Math.max(11, 12)))
            color: level === "red" ? Palette.statusUrgent : "transparent"
            color: Qt.rgba(Palette.accent.r, Palette.accent.g, Palette.accent.b, 0.3)
            text: "Palette.noSuchRole; columns: DesktopStyle.px(7)"
            targetCellWidth: DesktopStyle.px(240)
            columns: Math.max(1, Math.floor(width / targetCellWidth))
            border.width: focused ? DesktopStyle.px(2) : 1
            axis { x: 0; y: 1 }
        """
        self.assertEqual(list(token_violations(code)), [])
