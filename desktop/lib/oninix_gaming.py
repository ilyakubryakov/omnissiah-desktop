"""The reversible AI/window part of the shared desktop Game mode."""
import os
from pathlib import Path
import subprocess
import sys
import time

import oninix_gameapps as gameapps

UNITS = ('ollama.service', 'open-webui.service', 'comfyui.service')


def command(args, timeout=120):
    return subprocess.run(args, check=True, capture_output=True, timeout=timeout).stdout


def active_units():
    result = []
    for unit in UNITS:
        state = command(['systemctl', 'show', unit, '--property=ActiveState', '--value']).decode().strip()
        if state in {'active', 'activating', 'reloading'}:
            result.append(unit)
    return result


def services(verb, units):
    if units:
        # Fixed unit allowlist; existing Polkit rules grant these operations only
        # to the active local user. No generic privileged command is needed.
        if any(unit not in UNITS for unit in units):
            raise ValueError('Invalid saved AI service')
        # systemd's batch job API omits the single-unit Polkit detail.
        for unit in units:
            command(['/run/current-system/sw/bin/systemctl', '--no-ask-password', verb, unit])


def windows(on):
    if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        reply = command(['hyprctl', 'eval', 'require("gaming").set(' + ('true' if on else 'false') + ')'])
        if reply.decode().strip() != 'ok':
            raise RuntimeError('Could not change game fullscreen policy')


def resume(units):
    # open-webui Wants=ollama. Restore an intentionally WebUI-only baseline too,
    # while preserving an Ollama that the owner manually started during gaming.
    web_only = 'open-webui.service' in units and 'ollama.service' not in units
    ollama_was_running = web_only and 'ollama.service' in active_units()
    services('start', units)
    if web_only and not ollama_was_running:
        services('stop', ['ollama.service'])


PERFORMANCE_UNIT = 'oninix-game-performance.service'


def scheduler_available():
    return Path('/etc/systemd/system', PERFORMANCE_UNIT).exists()


def scheduler_service(verb):
    # Polkit grants only this fixed unit's start/stop to the active local user.
    command(['/run/current-system/sw/bin/systemctl', '--no-ask-password', verb, PERFORMANCE_UNIT])


def loader_property(name):
    # Properties are readable without privileges; changes go through the unit.
    return command(['busctl', '--system', 'get-property', 'org.scx.Loader', '/org/scx/Loader',
                    'org.scx.Loader', name]).decode().strip()


def lavd_baseline():
    """True when scx_loader runs plain LAVD in Auto mode, the state the unit may own."""
    try:
        return (loader_property('CurrentScheduler') == 's "scx_lavd"'
                and loader_property('CurrentSchedulerArgs') == 'as 0'
                and loader_property('SchedulerMode') == 'u 0')
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return False


def scheduler_enter():
    if not scheduler_available():
        return False
    state = command(['systemctl', 'show', PERFORMANCE_UNIT, '--property=ActiveState', '--value']).decode().strip()
    if state == 'active':
        return False  # Do not own a profile the user already enabled.
    if not lavd_baseline():
        return False
    scheduler_service('start')
    state = command(['systemctl', 'show', PERFORMANCE_UNIT, '--property=ActiveState', '--value']).decode().strip()
    if state != 'active':
        scheduler_service('stop')
        raise RuntimeError('LAVD performance profile did not start')
    return True


def scheduler_leave(owned):
    if owned:
        scheduler_service('stop')


def enter():
    gameapps.progress('on', 'Pausing local AI')
    before = gameapps.vram_used()
    units = active_units()
    scheduler_owned = False
    try:
        services('stop', units)
        if active_units():
            raise RuntimeError('Local AI is still running')
        scheduler_owned = scheduler_enter()
        windows(True)
    except Exception:
        try:
            windows(False)
        finally:
            try:
                scheduler_leave(scheduler_owned)
            finally:
                resume(units)
        gameapps.progress('on', 'Could not turn Game mode on', 'error')
        raise
    # Last, and never fatal: Game mode is useful even when an app stays open.
    try:
        apps = gameapps.close()
    except Exception as error:
        print('Game mode could not close desktop apps: %s' % error, file=sys.stderr)
        apps = {}
    # Freed memory shows up once the driver has torn the contexts down.
    time.sleep(1)
    after = gameapps.vram_used()
    freed = before - after if before is not None and after is not None else 0
    gameapps.progress('on', 'Freed %.1f GB of VRAM' % (freed / 1024) if freed >= 100 else 'Ready to play', 'done')
    return {'units': units, 'scheduler_owned': scheduler_owned, 'apps': apps}


def leave(snapshot):
    units = snapshot.get('units', [])
    owned = snapshot.get('scheduler_owned', False)
    gameapps.progress('off', 'Resuming local AI')
    try:
        windows(False)
        scheduler_leave(owned)
        resume(units)
    except Exception:
        # Keep the old mode truthful if restoring AI was rejected or interrupted.
        try:
            services('stop', units)
        finally:
            try:
                if owned:
                    scheduler_service('start')
            finally:
                windows(True)
        gameapps.progress('off', 'Could not turn Game mode off', 'error')
        raise
    try:
        arranging = gameapps.restore(snapshot.get('apps') or {})
    except Exception as error:
        print('Game mode could not reopen desktop apps: %s' % error, file=sys.stderr)
        gameapps.progress('off', 'Some apps did not reopen', 'error')
        return
    if not arranging:
        gameapps.progress('off', 'Desktop restored', 'done')
