{ config, lib, pkgs, ... }:
lib.mkIf config.oninix.enable {
  systemd.services.systemd-timedated.restartTriggers = lib.mkIf (config.time.timeZone != null) [
    (pkgs.writeText "oninix-time-zone" config.time.timeZone)
  ];
  environment.systemPackages = with pkgs; [ bubblewrap gum nvd passt ];
}
