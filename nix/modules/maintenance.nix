{ config, lib, pkgs, ... }:
let
  doctor = "/run/current-system/sw/bin/oninix-doctor";
  crashWatch = "/run/current-system/sw/bin/oninix-crash-watch";
  nvd = lib.getExe pkgs.nvd;
  btrfsPresent = lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems);
  background = description: command: {
    inherit description;
    partOf = [ "graphical-session.target" ];
    path = [ "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = command;
      Nice = 15;
      IOSchedulingClass = "idle";
    };
  };
in
lib.mkIf config.oninix.enable {
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 30d";
  };
  services.btrfs.autoScrub = {
    enable = lib.mkDefault btrfsPresent;
    interval = lib.mkDefault "Sun *-*-01..07 04:00:00";
  };

  systemd.user.services.oninix-doctor = background "Refresh OniNix Doctor" "${doctor} --cache";
  systemd.user.services.oninix-crash-watch = background "Report recent application coredumps" crashWatch;
  systemd.user.timers.oninix-doctor = {
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "10s";
      OnUnitActiveSec = "15min";
    };
  };
  systemd.user.timers.oninix-crash-watch = {
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "30s";
      OnUnitActiveSec = "1min";
      AccuracySec = "5s";
    };
  };

  system.activationScripts.oninix-generation-diff = {
    deps = [ "specialfs" ];
    text = ''
      previous=$(readlink -f /run/current-system)
      if [ -x "$previous/bin/switch-to-configuration" ] && [ "$previous" != "$systemConfig" ]; then
        state=/var/lib/oninix-maintenance
        install -d -m 0755 "$state"
        diff=$(mktemp "$state/.last-rebuild.XXXXXX")
        if {
          printf 'From %s\nTo   %s\nAt   %s\n\n' "$previous" "$systemConfig" "$(date -Is)"
          ${nvd} --nix-bin-dir=${config.nix.package}/bin diff "$previous" "$systemConfig"
        } > "$diff"; then
          chmod 0644 "$diff"
          mv -f "$diff" "$state/last-rebuild.txt"
        else
          rm -f "$diff"
        fi
      fi
    '';
  };
}
