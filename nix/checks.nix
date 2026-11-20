{ lib, runCommand, nodejs, python3, lua5_4, nix, bash, qt6 }:
let
  src = lib.cleanSource ../.;
in
runCommand "oninix-checks" { nativeBuildInputs = [ nodejs python3 lua5_4 nix bash qt6.qtdeclarative ]; } ''
  cp -r ${src} repo
  chmod -R u+w repo
  cd repo
  export LANG=C.UTF-8
  for test in desktop/quickshell/tests/*.cjs; do
    TZ=Europe/Vilnius node "$test"
  done
  for tool in oninix-install nix/layer/oninix-layer-* desktop/bin/* desktop/hypr/scripts/*; do
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
  import importlib.machinery, importlib.util, json, pathlib, subprocess, tempfile
  from unittest.mock import patch
  spec = importlib.util.spec_from_file_location('installer', 'nix/installer/oninix-installer.py')
  m = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(m)
  answers = {'device': '/dev/vda', 'encrypt': True, 'luks': 'x', 'fullname': 'Demo "Quoted" User', 'user': 'demo',
             'password': 'p', 'hostname': 'oninix', 'timezone': 'Europe/Vilnius', 'layout': 'us,ru', 'gpu': 'amd',
             'laptop': True, 'virt': "", 'features': ['gaming', 'ai']}
  for text in (m.settings(answers), m.disko_config('/dev/vda', True), m.disko_config('/dev/nvme0n1', False)):
      subprocess.run(['nix-instantiate', '--readonly-mode', '--parse', '-'], input=text, text=True, check=True, stdout=subprocess.DEVNULL)
  disk = {'type': 'disk', 'path': '/dev/vda', 'model': str(), 'size': 64000000000, 'ro': False, 'mountpoints': [None]}
  mounted = {**disk, 'path': '/dev/vdb', 'children': [{'mountpoints': [None], 'children': [{'mountpoints': ['/iso']}]}]}
  with patch.object(subprocess, 'check_output', return_value=json.dumps({'blockdevices': [disk, mounted]})):
      assert [device for device, _ in m.disks()] == ['/dev/vda']

  loader = importlib.machinery.SourceFileLoader('spirit', 'desktop/bin/oninix-spirit')
  spec = importlib.util.spec_from_loader('spirit', loader)
  spirit = importlib.util.module_from_spec(spec)
  loader.exec_module(spirit)
  before = '{\n  extraPackages = with pkgs; [ ];\n}'
  after = before.replace('[ ]', '[ hello kdePackages.kate ]')
  assert spirit.layer_shape(before) == spirit.layer_shape(after)
  assert spirit.layer_shape(after + ' # outside') != spirit.layer_shape(before)
  try:
      spirit.layer_shape(before.replace('[ ]', '[ (pkgs.hello.override {}) ]'))
  except RuntimeError:
      pass
  else:
      raise AssertionError('Expected rejection of a layer package expression')
  with tempfile.TemporaryDirectory() as folder:
      original = pathlib.Path(folder) / 'auth.json'
      refreshed = pathlib.Path(folder) / 'new-auth.json'
      initial = b'{"auth":"old"}'
      original.write_bytes(initial)
      refreshed.write_text('{"auth":"refreshed"}')
      spirit.keep_refreshed_login(original, refreshed, initial)
      assert original.read_bytes() == refreshed.read_bytes()
      assert original.stat().st_mode & 0o777 == 0o600
      original.write_text('{"auth":"updated in another session"}')
      spirit.keep_refreshed_login(original, refreshed, initial)
      assert original.read_text() == '{"auth":"updated in another session"}'
  EOF
  touch $out
''
