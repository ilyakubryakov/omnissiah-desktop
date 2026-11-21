{ config, lib, pkgs, ... }:
let
  cfg = config.oninix.backup;
  home = config.users.users.${config.oninix.user.name}.home;
  machine = "/etc/nixos";
  state = "/var/lib/oninix-backup";
  mount = lib.escapeShellArg cfg.mountPoint;
  password = lib.escapeShellArg cfg.passwordFile;
  probe = pkgs.writeText "oninix-restore-test" "OniNix backup restore test\n";
  tool = pkgs.writeShellApplication {
    name = "oninix-backup";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils pkgs.findutils pkgs.restic pkgs.util-linux ];
    text = ''
      usage() {
        printf '%s\n' 'sudo oninix-backup init|run|snapshots|check|restore SNAPSHOT EMPTY_DIRECTORY'
      }
      action=''${1:-help}
      case "$action" in
        help|--help) usage; exit 0 ;;
        init|run|snapshots|check) if [[ $# != 1 ]]; then usage >&2; exit 2; fi ;;
        restore) if [[ $# != 3 ]]; then usage >&2; exit 2; fi ;;
        *) usage >&2; exit 2 ;;
      esac
      die() { printf '%s\n' "$1" >&2; exit 1; }
      if (( EUID != 0 )); then die 'Run oninix-backup with sudo.'; fi
      unset RESTIC_REPOSITORY_FILE RESTIC_PASSWORD RESTIC_PASSWORD_COMMAND
      umask 077
      exec 9>/run/lock/oninix-backup.lock
      flock 9
      if ! mountpoint -q -- ${mount}; then
        die 'The backup disk is not mounted.'
      fi
      cd -P -- ${mount}
      if [[ "$PWD" != ${mount} || "$(stat -c %u .)" != 0 ]]; then
        die 'The backup mount must have its configured path and be owned by root.'
      fi
      if (( 8#$(stat -c %a .) & 0022 )); then
        die 'The backup mount must only be writable by root.'
      fi
      export RESTIC_PASSWORD_FILE=${password}
      if [[ ! -s "$RESTIC_PASSWORD_FILE" || -L "$RESTIC_PASSWORD_FILE" || "$(stat -c %u "$RESTIC_PASSWORD_FILE")" != 0 ]]; then
        die 'Set a root-owned backup password file.'
      fi
      if (( 8#$(stat -c %a "$RESTIC_PASSWORD_FILE") & 0077 )); then
        die 'Set the password file permissions to 0600 or 0400.'
      fi
      export RESTIC_REPOSITORY="$PWD/oninix-restic"
      export RESTIC_CACHE_DIR=/var/cache/oninix-backup
      install -d -m 0700 "$RESTIC_CACHE_DIR"
      if [[ -L "$RESTIC_REPOSITORY" ]]; then die 'The backup repository cannot be a symlink.'; fi
      if [[ "$action" != init && ! -f "$RESTIC_REPOSITORY/config" ]]; then
        die 'Initialize the backup repository on this disk with sudo oninix-backup init.'
      fi
      sources=( ${lib.escapeShellArg home} ${lib.escapeShellArg machine} )
      local_state=${lib.escapeShellArg state}
      record() {
        local tmp
        tmp=$(mktemp "$local_state/status/.stamp.XXXXXX")
        date +%s > "$tmp"
        chmod 0644 "$tmp"
        mv -f -- "$tmp" "$local_state/status/$1"
      }
      case "$action" in
        init)
          if [[ -e "$RESTIC_REPOSITORY" ]]; then die 'The backup repository path already exists.'; fi
          restic init
          ;;
        run)
          for source in "''${sources[@]}"; do
            if [[ ! -d "$source" || -L "$source" ]]; then die "Backup source is missing or is a symlink: $source"; fi
          done
          install -m 0644 ${probe} "$local_state/probe"
          restic backup --tag oninix --one-file-system \
            --exclude "$RESTIC_PASSWORD_FILE" \
            --exclude ${lib.escapeShellArg "${home}/.cache"} \
            --exclude ${lib.escapeShellArg "${home}/.local/share/Trash"} \
            -- "''${sources[@]}" "$local_state/probe"
          record snapshot
          ;;
        snapshots) restic snapshots --tag oninix ;;
        check)
          restic check --read-data-subset=5%
          restic dump --tag oninix latest "$local_state/probe" | cmp - ${probe}
          record verified
          ;;
        restore)
          if [[ "$3" != /* || ! -d "$3" || -L "$3" || -n "$(find "$3" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
            die 'Use an existing empty absolute restore directory.'
          fi
          restic restore --tag oninix --verify --target "$3" -- "$2"
          ;;
      esac
    '';
  };
  guard = {
    unitConfig.ConditionPathIsMountPoint = cfg.mountPoint;
    serviceConfig = {
      Type = "oneshot";
      Nice = 15;
      IOSchedulingClass = "idle";
    };
  };
in
{
  options.oninix.backup = {
    enable = lib.mkEnableOption "encrypted local backup of the main user's home and /etc/nixos";
    mountPoint = lib.mkOption {
      type = lib.types.strMatching "/[^\n\r]+";
      default = "/mnt/oninix-backup";
      description = "Stable root-owned mount point for the local backup disk. Run sudo oninix-backup init once after mounting it.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.strMatching "/[^\n\r]+";
      default = "/etc/oninix/backup-password";
      description = "Root-only password file on the machine, outside the Nix store. Keep a separate copy of the password for recovery.";
    };
  };

  config = lib.mkIf (config.oninix.enable && cfg.enable) {
    assertions = [{
      assertion = lib.all (dir: cfg.mountPoint != dir && !lib.hasPrefix (dir + "/") cfg.mountPoint)
        [ home machine "/nix/store" state ];
      message = "The OniNix backup disk must mount outside the backup sources and the Nix store.";
    }];
    environment.systemPackages = [ tool ];
    systemd.tmpfiles.rules = [
      "d ${state} 0755 root root -"
      "d ${state}/status 0755 root root -"
    ];
    systemd.services.oninix-backup = lib.recursiveUpdate guard {
      description = "Back up the OniNix home and system configuration";
      serviceConfig.ExecStart = "${lib.getExe tool} run";
    };
    systemd.services.oninix-backup-check = lib.recursiveUpdate guard {
      description = "Check the OniNix backup and restore its test file";
      serviceConfig.ExecStart = "${lib.getExe tool} check";
    };
    systemd.timers.oninix-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "15min";
        Persistent = true;
      };
    };
    systemd.timers.oninix-backup-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };
    };
  };
}
