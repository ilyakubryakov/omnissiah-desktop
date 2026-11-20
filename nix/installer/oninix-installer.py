import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BRASS, GLOW, BONE, CRIMSON, MUTED = '#c1893e', '#e0a95a', '#d9c4a3', '#b8473a', '#a68a6f'
for key, value in {
    'GUM_CHOOSE_CURSOR_FOREGROUND': GLOW, 'GUM_CHOOSE_SELECTED_FOREGROUND': BRASS,
    'GUM_CHOOSE_HEADER_FOREGROUND': GLOW, 'GUM_CHOOSE_ITEM_FOREGROUND': BONE,
    'GUM_INPUT_CURSOR_FOREGROUND': GLOW, 'GUM_INPUT_PROMPT_FOREGROUND': BRASS,
    'GUM_INPUT_HEADER_FOREGROUND': GLOW, 'GUM_FILTER_INDICATOR_FOREGROUND': GLOW,
    'GUM_FILTER_MATCH_FOREGROUND': BRASS, 'GUM_FILTER_HEADER_FOREGROUND': GLOW,
    'GUM_FILTER_PROMPT_FOREGROUND': BRASS, 'GUM_CONFIRM_PROMPT_FOREGROUND': GLOW,
    'GUM_CONFIRM_SELECTED_BACKGROUND': BRASS, 'GUM_CONFIRM_SELECTED_FOREGROUND': '#121010',
    'GUM_CONFIRM_UNSELECTED_BACKGROUND': '#3a2418', 'GUM_CONFIRM_UNSELECTED_FOREGROUND': BONE,
    'GUM_WRITE_HEADER_FOREGROUND': GLOW, 'GUM_WRITE_CURSOR_FOREGROUND': GLOW,
}.items():
    os.environ.setdefault(key, value)

TEMPLATE = Path(os.environ['ONINIX_TEMPLATE'])
SOURCE = os.environ.get('ONINIX_SOURCE', '')
TARGET = Path('/mnt')
FEATURES = [
    ('gaming', 'Gaming: Steam, Proton, Game mode, launchers'),
    ('coding', 'Coding: editors and developer tools'),
    ('music', 'Music: low-latency audio and a DAW'),
    ('ai', 'AI: Claude, Codex and local models'),
]
LAYOUTS = ['us', 'us,ru', 'us,de', 'us,fr', 'us,es', 'us,ua', 'gb', 'de', 'fr']

def gum(*args, stdin=None):
    result = subprocess.run(['gum', *args], input=stdin, stdout=subprocess.PIPE, text=True)
    if result.returncode == 130:
        raise SystemExit('Installation cancelled.')
    return result

def say(text, color=GLOW):
    subprocess.run(['gum', 'style', '--foreground', color, '--bold', text])

def choose(header, options, selected=None, many=False):
    args = ['choose', '--header', header]
    if many:
        args.append('--no-limit')
    if selected:
        args += ['--selected', ','.join(selected)]
    out = gum(*args, *options).stdout.strip()
    return [line for line in out.splitlines() if line] if many else out

def ask(header, value='', placeholder='', password=False):
    args = ['input', '--header', header, '--value', value, '--placeholder', placeholder]
    if password:
        args.append('--password')
    return gum(*args).stdout.strip()

def confirm(text, default=True):
    args = ['confirm', text] + ([] if default else ['--default=false'])
    return subprocess.run(['gum', *args]).returncode == 0

def run(args, **kwargs):
    print('$ ' + ' '.join(args), flush=True)
    subprocess.run(args, check=True, **kwargs)

def detect_gpu():
    try:
        out = subprocess.run(['lspci', '-nn'], capture_output=True, text=True).stdout
    except OSError:
        return 'none'
    lines = [line for line in out.splitlines() if re.search(r'VGA|3D|Display', line)]
    joined = '\n'.join(lines)
    if '[10de:' in joined:
        return 'nvidia'
    if '[1002:' in joined:
        return 'amd'
    if '[8086:' in joined:
        return 'intel'
    return 'none'

def detect_laptop():
    return any(Path('/sys/class/power_supply').glob('BAT*'))

def detect_virt():
    result = subprocess.run(['systemd-detect-virt'], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ''

def disks():
    data = json.loads(subprocess.run(['lsblk', '-J', '-d', '-b', '-o', 'NAME,PATH,SIZE,MODEL,TYPE,RM,RO'],
                                     capture_output=True, text=True, check=True).stdout)
    live = subprocess.run(['findmnt', '-n', '-o', 'SOURCE', '/iso'], capture_output=True, text=True).stdout.strip()
    result = []
    for dev in data['blockdevices']:
        if dev['type'] != 'disk' or dev.get('ro') or (live and live.startswith(dev['path'])):
            continue
        size = int(dev['size']) / 1e9
        if size < 32:
            continue
        model = (dev.get('model') or '').strip() or 'disk'
        result.append((dev['path'], f"{dev['path']}  {size:.0f} GB  {model}"))
    return result

def disko_config(device, encrypt, password_file=None):
    btrfs = '''{
          type = "btrfs";
          extraArgs = [ "-f" ];
          subvolumes = {
            "@" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
            "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
            "@nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
          };
        }'''
    password_line = f'        passwordFile = {nix_string(str(password_file))};\n' if password_file else ''
    root = btrfs if not encrypt else '''{
        type = "luks";
        name = "cryptroot";
''' + password_line + '''        settings.allowDiscards = true;
        content = ''' + btrfs + ''';
      }'''
    return '''{
  disko.devices.disk.main = {
    type = "disk";
    device = "''' + device + '''";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; mountOptions = [ "umask=0077" ]; };
        };
        root = {
          size = "100%";
          content = ''' + root + ''';
        };
      };
    };
  };
}
'''

def nix_string(value):
    return json.dumps(value, ensure_ascii=False).replace('${', r'\${')

def settings(answers):
    features = '\n'.join(f'      {key} = {"true" if key in answers["features"] else "false"};' for key, _ in FEATURES)
    return f'''{{
  oninix = {{
    enable = true;
    user = {{
      name = {nix_string(answers["user"])};
      description = {nix_string(answers["fullname"])};
    }};
    hardware = {{
      gpu = {nix_string(answers["gpu"])};
      laptop = {"true" if answers["laptop"] else "false"};
    }};
    features = {{
{features}
    }};
  }};

  networking.hostName = {nix_string(answers["hostname"])};
  time.timeZone = {nix_string(answers["timezone"])};
  services.xserver.xkb.layout = {nix_string(answers["layout"])};
  console.useXkbConfig = true;
  system.stateVersion = "26.11";
}}
'''

def ask_password(label):
    while True:
        first = ask(label, password=True)
        if len(first) < 4:
            say('Use at least 4 characters.', CRIMSON)
            continue
        if first == ask('Repeat ' + label.lower(), password=True):
            return first
        say('The passwords do not match.', CRIMSON)

def collect():
    say('OniNix installer · the machine spirit awaits')
    if not Path('/sys/firmware/efi').exists():
        raise SystemExit('OniNix needs a UEFI boot. Switch the firmware to UEFI and start again.')
    if subprocess.run(['ping', '-c', '1', '-W', '3', 'cache.nixos.org'], capture_output=True).returncode != 0:
        say('No network. Connect with the panel or `nmtui`, then press Enter.', BRASS)
        input()
    targets = disks()
    if not targets:
        raise SystemExit('No disk of 32 GB or more was found.')
    label = choose('Install OniNix on which disk? Everything on it will be erased.', [t[1] for t in targets])
    device = next(path for path, text in targets if text == label)
    encrypt = confirm('Encrypt the disk (LUKS)?', default=False)
    luks = ask_password('Disk encryption passphrase') if encrypt else ''
    fullname = ask('Your name', placeholder='Ilya')
    default_user = re.sub(r'[^a-z0-9_-]', '', fullname.lower().split(' ')[0]) or 'user'
    user = ask('Login name', value=default_user)
    while not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', user):
        say('Use lowercase letters, digits, - or _.', CRIMSON)
        user = ask('Login name', value=default_user)
    password = ask_password('Password for ' + user)
    hostname = ask('Computer name', value='oninix')
    zones = subprocess.run(['timedatectl', 'list-timezones'], capture_output=True, text=True).stdout
    timezone = gum('filter', '--header', 'Time zone', '--placeholder', 'Type a city',
                   stdin=zones).stdout.strip() or 'UTC'
    layout = choose('Keyboard layouts (switch with Caps Lock)', LAYOUTS)
    gpu, laptop, virt = detect_gpu(), detect_laptop(), detect_virt()
    gpu = choose(f'Graphics: detected {gpu}', ['nvidia', 'amd', 'intel', 'none'], selected=[gpu])
    picked = choose('What should OniNix bring? X toggles, Enter confirms.',
                    [text for _, text in FEATURES], selected=[FEATURES[1][1]], many=True)
    features = [key for key, text in FEATURES if text in picked]
    return {'device': device, 'encrypt': encrypt, 'luks': luks, 'fullname': fullname, 'user': user,
            'password': password, 'hostname': hostname, 'timezone': timezone, 'layout': layout,
            'gpu': gpu, 'laptop': laptop, 'virt': virt, 'features': features}

def install(answers):
    with tempfile.TemporaryDirectory() as work:
        disko_file = Path(work) / 'disko.nix'
        password_file = None
        if answers['encrypt']:
            password_file = Path(work) / 'luks-passphrase'
            with os.fdopen(os.open(password_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as handle:
                handle.write(answers['luks'])
        disko_file.write_text(disko_config(answers['device'], answers['encrypt'], password_file))
        try:
            run(['disko', '--mode', 'destroy,format,mount', '--yes-wipe-all-disks', str(disko_file)])
        finally:
            if password_file:
                password_file.unlink()
        etc = TARGET / 'etc/nixos'
        etc.mkdir(parents=True, exist_ok=True)
        run(['nixos-generate-config', '--no-filesystems', '--root', str(TARGET)])
        (etc / 'configuration.nix').unlink(missing_ok=True)
        shutil.copy(TEMPLATE / 'flake.nix', etc / 'flake.nix')
        (etc / 'disko.nix').write_text(disko_config(answers['device'], answers['encrypt']))
    (etc / 'settings.nix').write_text(settings(answers))
    for name in ('flake.nix', 'disko.nix', 'settings.nix'):
        os.chmod(etc / name, 0o644)
    lock = ['nix', '--extra-experimental-features', 'nix-command flakes', 'flake', 'lock', str(etc)]
    if SOURCE:
        lock += ['--override-input', 'oninix', 'path:' + SOURCE]
    run(lock)
    run(['nixos-install', '--flake', f'{etc}#oninix', '--no-root-passwd', '--no-channel-copy'])
    run(['nixos-enter', '--root', str(TARGET), '--', 'chpasswd'],
        input=f'{answers["user"]}:{answers["password"]}\n', text=True)

def main():
    if os.geteuid() != 0:
        os.execvp('sudo', ['sudo', '--preserve-env=ONINIX_TEMPLATE,ONINIX_SOURCE,PATH', sys.executable, *sys.argv])
    answers = collect()
    say('Summary', BRASS)
    print(f"  Disk        {answers['device']} (erased{', encrypted' if answers['encrypt'] else ''})")
    print(f"  User        {answers['user']} ({answers['fullname']})")
    print(f"  Computer    {answers['hostname']} · {answers['timezone']} · {answers['layout']}")
    print(f"  Graphics    {answers['gpu']}{' · laptop' if answers['laptop'] else ''}")
    print(f"  Sets        {', '.join(answers['features']) or 'base desktop only'}")
    if not confirm('Erase the disk and install OniNix?', default=False):
        raise SystemExit('Nothing was changed.')
    install(answers)
    say('OniNix is installed. The machine spirit sleeps until you reboot.')
    if confirm('Reboot now?'):
        run(['systemctl', 'reboot'])

if __name__ == '__main__':
    main()
