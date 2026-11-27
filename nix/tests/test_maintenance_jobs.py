import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXPRESSION = '''
let
  demo = (builtins.getFlake (toString ./.)).nixosConfigurations.demo;
  c = (demo.extendModules { modules = [ { oninix.backup.enable = true; } ]; }).config;
  script = command: { inherit command; drv = builtins.head (builtins.attrNames (builtins.getContext command)); };
  queue = scope: job:
    let
      service = scope.${job}.serviceConfig;
      catchUp = scope.oninix-game-catch-up.serviceConfig;
    in {
      inherit job;
      condition = script (builtins.head service.ExecCondition);
      post = builtins.head service.ExecStartPost;
      catchup = script catchUp.ExecStart;
      logLevel = catchUp.LogLevelMax;
    };
in {
  system = queue c.systemd.services "oninix-backup";
  user = queue c.systemd.user.services "oninix-update-check";
  backup = script c.systemd.services.oninix-backup.serviceConfig.ExecStart;
  home = c.users.users.${c.oninix.user.name}.home;
}
'''


def nix(*args):
    return subprocess.check_output(['nix', *args], cwd=ROOT, text=True, timeout=60)


def script_text(info):
    value = json.loads(nix('derivation', 'show', '--offline', info['drv']))
    drv, = value.get('derivations', value).values()
    attrs = drv.get('structuredAttrs') or drv['env']
    return attrs['text']


def evaluated():
    return json.loads(nix('eval', '--offline', '--impure', '--json', '--expr', EXPRESSION))


@unittest.skipUnless(shutil.which('nix'), 'Nix evaluation is required')
class GameDeferTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = evaluated()
        for scope in ('system', 'user'):
            for hook in ('condition', 'catchup'):
                item = cls.config[scope][hook]
                item['script'] = script_text(item)

    def setup_queue(self, scope):
        cfg = self.config[scope]
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        state = root / 'queue'
        state.mkdir()
        game, failed, race, calls = (root / name for name in ('game', 'failed', 'race', 'calls'))
        condition, control, catchup, detector = (root / name for name in ('condition', 'systemctl', 'catchup', 'detector'))
        job = cfg['job']
        self.assertEqual(cfg['logLevel'], 'notice')
        self.assertEqual(cfg['condition']['command'].startswith('+'), scope == 'system')
        self.assertEqual(cfg['post'].startswith('+'), scope == 'system')
        detector.write_text(f'#!/bin/sh\ntest -e {shlex.quote(str(game))}\n')
        detector.chmod(0o700)

        def rewrite(script):
            return re.sub(r'/nix/store/\S+-oninix-game-active', str(detector), script)

        condition.write_text(rewrite(cfg['condition']['script']))
        post = shlex.split(cfg['post'].lstrip('+'))
        self.assertEqual(Path(post[0]).name, 'rm')
        post_target = str(state / Path(post[-1]).name)
        control.write_text(f'''#!/bin/sh
if [ "$1" = --user ]; then shift; fi
[ "$#" -eq 4 ] && [ "$1 $2 $3" = 'start --wait --' ] || exit 98
printf '%s\n' "$4" >> "{calls}"
if [ -e "{race}" ]; then touch "{game}"; fi
bash "{condition}" "{state}" "{job}" || exit 0
[ ! -e "{failed}" ] || exit 1
rm -f -- "{post_target}"
''')
        control.chmod(0o700)
        catchup.write_text(re.sub(r'/nix/store/\S+/bin/systemctl', str(control), rewrite(cfg['catchup']['script'])))
        run_condition = lambda: subprocess.run(['bash', condition, state, job], capture_output=True, text=True)
        run_catchup = lambda: subprocess.check_output(['bash', catchup, state], text=True)
        return job, state, game, failed, race, calls, run_condition, run_catchup

    def test_queue_handles_game_races_failures_and_unknown_entries(self):
        for scope in ('system', 'user'):
            with self.subTest(scope=scope):
                job, state, game, failed, race, calls, condition, catchup = self.setup_queue(scope)
                queued = state / job
                self.assertEqual(condition().returncode, 0)
                game.touch()
                self.assertEqual(condition().returncode, 1)
                self.assertTrue(queued.exists())
                catchup()
                self.assertFalse(calls.exists())

                game.unlink()
                race.touch()
                catchup()
                self.assertTrue(queued.exists())
                self.assertTrue(game.exists())
                game.unlink()
                race.unlink()

                failed.touch()
                self.assertIn(f'<4>{job} failed after Game mode', catchup())
                self.assertTrue(queued.exists())
                failed.unlink()
                (state / 'unrelated').touch()
                self.assertEqual(catchup(), '')
                self.assertFalse(queued.exists())
                self.assertEqual(calls.read_text().splitlines(), [job + '.service'] * 3)


@unittest.skipUnless(shutil.which('nix') and shutil.which('restic'), 'Nix and Restic are required')
class BackupTests(unittest.TestCase):
    def test_snapshot_keeps_home_data_and_excludes_keywatch(self):
        cfg = evaluated()
        recipe = re.search(r'^\s*(restic backup .*?)^\s*record snapshot$', script_text(cfg['backup']),
                           re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(recipe)
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        home, state = root / 'home', root / 'state'
        private = home / '.local/state/oninix/keywatch'
        private.mkdir(parents=True)
        state.mkdir()
        (private / 'report.json').write_text('{}')
        (home / 'document').write_text('test')
        (state / 'probe').write_text('restore probe')
        password = root / 'password'
        password.write_text('test repository password')
        env = {'PATH': os.environ['PATH'], 'HOME': str(home), 'RESTIC_REPOSITORY': str(root / 'repo'),
               'RESTIC_PASSWORD_FILE': str(password)}

        def restic(*args):
            return subprocess.check_output(['restic', *args], env=env, text=True, timeout=30)

        restic('init')
        backup = recipe[1].replace(cfg['home'], str(home))
        subprocess.run(['bash', '-ec', 'sources=("$1"); local_state=$2; ' + backup,
                        '_', str(home), str(state)], env=env, check=True, capture_output=True, timeout=30)
        self.assertEqual(restic('dump', 'latest', str(home / 'document')), 'test')
        self.assertEqual(restic('dump', 'latest', str(state / 'probe')), 'restore probe')
        self.assertNotIn(str(private), restic('ls', 'latest'))


if __name__ == '__main__':
    unittest.main()
