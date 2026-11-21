{ config, lib, pkgs, utils, ... }:
let
  cfg = config.oninix;
  systemState = "/var/lib/oninix-game-deferred";
  userState = "%S/oninix-game-deferred";
  systemctl = "${config.systemd.package}/bin/systemctl";
  gameActive = pkgs.writeScript "oninix-game-active" ''
    #!${lib.getExe pkgs.python3}
    import json
    import os
    import pwd
    import stat
    import sys
    from contextlib import ExitStack

    try:
        uid = pwd.getpwnam(sys.argv[1]).pw_uid if len(sys.argv) > 1 else os.getuid()
        with ExitStack() as stack:
            path = f"/run/user/{uid}/oninix-desktop"
            directory = os.open(path, os.O_DIRECTORY | os.O_NOFOLLOW)
            stack.callback(os.close, directory)
            fd = os.open("mode.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
            stack.callback(os.close, fd)
            info = os.fstat(fd)
            limit = 1024 * 1024
            if not stat.S_ISREG(info.st_mode) or info.st_uid != uid or info.st_size > limit:
                sys.exit(1)
            mode = json.loads(os.read(fd, limit + 1))
            sys.exit(0 if isinstance(mode, dict) and mode.get("name") == "game" else 1)
    except (OSError, KeyError, ValueError, RecursionError):
        sys.exit(1)
  '';
  systemGame = "${gameActive} ${lib.escapeShellArg cfg.user.name}";
  queue = scope: state: check: units:
    let
      defer = pkgs.writeShellScript "oninix-defer-${scope}" ''
        if ${check}; then
          umask 077
          mkdir -p -- "$1" && touch -- "$1/$2" || exit 255
          printf '%s waits until Game mode ends.\n' "$2"
          exit 1
        fi
      '';
      catchUp = pkgs.writeShellScript "oninix-catch-up-${scope}" ''
        for unit in ${lib.escapeShellArgs units}; do
          [[ -f "$1/$unit" ]] || continue
          if ${check}; then exit 0; fi
          ${systemctl} ${lib.optionalString (scope == "user") "--user"} start --wait -- "$unit.service" || true
        done
      '';
      privileged = lib.optionalString (scope == "system") "+";
    in
    {
      condition = name: lib.mkBefore [ "${privileged}${defer} \"${state}\" ${name}" ];
      acknowledge = name: "${privileged}${pkgs.coreutils}/bin/rm -f -- \"${state}/${name}\"";
      service = {
        description = "Run ${scope} maintenance deferred by Game mode";
        unitConfig.ConditionDirectoryNotEmpty = state;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${catchUp} \"${state}\"";
          TimeoutStartSec = "infinity";
        };
      };
      timer = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/5";
          AccuracySec = "10s";
        };
      };
    };
  backups = lib.optionals cfg.backup.enable [ "oninix-backup" "oninix-backup-check" ];
  scheduled = backups
    ++ lib.optional config.nix.gc.automatic "nix-gc"
    ++ lib.optional config.nix.optimise.automatic "nix-optimise"
    ++ lib.optional config.services.fstrim.enable "fstrim"
    ++ lib.optional config.services.fwupd.enable "fwupd-refresh";
  scrub = config.services.btrfs.autoScrub;
  scrubUnits = lib.optionals scrub.enable (map (fs: "btrfs-scrub@${utils.escapeSystemdPath fs}") scrub.fileSystems);
  systemQueue = queue "system" systemState systemGame (scheduled ++ scrubUnits);
  userQueue = queue "user" userState "${gameActive}" [ "oninix-update-check" ];
in
lib.mkIf cfg.enable {
  systemd.services = lib.genAttrs scheduled (name: {
    serviceConfig = {
      ExecCondition = systemQueue.condition name;
      ExecStartPost = lib.mkAfter [ (systemQueue.acknowledge name) ];
    };
  }) // lib.optionalAttrs scrub.enable {
    "btrfs-scrub@".serviceConfig = {
      ExecCondition = systemQueue.condition "btrfs-scrub@%i";
      ExecStartPre = lib.mkAfter [ (systemQueue.acknowledge "btrfs-scrub@%i") ];
    };
  } // {
    oninix-game-catch-up = systemQueue.service;
  };
  systemd.timers.oninix-game-catch-up = systemQueue.timer;

  systemd.user.services.oninix-update-check.serviceConfig = {
    ExecCondition = userQueue.condition "oninix-update-check";
    ExecStartPost = lib.mkAfter [ (userQueue.acknowledge "oninix-update-check") ];
  };
  systemd.user.services.oninix-game-catch-up = userQueue.service;
  systemd.user.timers.oninix-game-catch-up = userQueue.timer;
}
