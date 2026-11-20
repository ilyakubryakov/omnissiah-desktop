{ lib, runCommand, nodejs, python3, lua5_4, nix, bash, qt6 }:
let
  src = lib.cleanSource ../.;
in
runCommand "oninix-checks" { nativeBuildInputs = [ nodejs python3 lua5_4 nix bash qt6.qtdeclarative ]; } ''
  cp -r ${src} repo
  chmod -R u+w repo
  cd repo
  for test in desktop/quickshell/tests/*.cjs; do
    TZ=Europe/Vilnius node "$test"
  done
  for tool in desktop/bin/* desktop/hypr/scripts/*; do
    case "$(head -1 "$tool")" in
      *python*) python3 -I -m py_compile "$tool" ;;
      *bash*|*sh) bash -n "$tool" ;;
    esac
  done
  python3 -I -m py_compile desktop/lib/*.py desktop/themes/*.py nix/installer/oninix-installer.py
  find desktop/quickshell -name '*.qml' -print0 | xargs -0 -n1 qmlformat > /dev/null
  for file in desktop/hypr/*.lua; do
    luac -p "$file"
  done
  export HOME=$TMPDIR NIX_STATE_DIR=$TMPDIR/nix-state
  ONINIX_TEMPLATE=nix/template python3 -I - <<'EOF'
  import importlib.util, subprocess
  spec = importlib.util.spec_from_file_location('installer', 'nix/installer/oninix-installer.py')
  m = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(m)
  answers = {'device': '/dev/vda', 'encrypt': True, 'luks': 'x', 'fullname': 'Demo "Quoted" User', 'user': 'demo',
             'password': 'p', 'hostname': 'oninix', 'timezone': 'Europe/Vilnius', 'layout': 'us,ru', 'gpu': 'amd',
             'laptop': True, 'virt': "", 'features': ['gaming', 'ai']}
  for text in (m.settings(answers), m.disko_config('/dev/vda', True), m.disko_config('/dev/nvme0n1', False)):
      subprocess.run(['nix-instantiate', '--readonly-mode', '--parse', '-'], input=text, text=True, check=True, stdout=subprocess.DEVNULL)
  EOF
  touch $out
''
