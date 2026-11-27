{ config, lib, ... }:
lib.mkIf config.oninix.enable {
  systemd.user.services.oninix-update-check = {
    description = "Daily OniNix update check";
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/oninix-maintenance daily";
      Nice = 15;
      IOSchedulingClass = "idle";
      LogLevelMax = "notice";
    };
  };
  systemd.user.timers.oninix-update-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "15min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = "10min";
    };
  };
}
