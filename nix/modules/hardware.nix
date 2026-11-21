{ config, lib, pkgs, ... }:
let
  cfg = config.oninix.hardware;
in
lib.mkIf config.oninix.enable (lib.mkMerge [
  { hardware.graphics.enable = true; }

  (lib.mkIf (cfg.gpu == "nvidia") {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
    };
  })

  (lib.mkIf (cfg.gpu == "amd") {
    services.xserver.videoDrivers = [ "amdgpu" ];
  })

  (lib.mkIf cfg.laptop {
    services.logind.settings.Login.HandleLidSwitch = "suspend";
    services.thermald.enable = lib.mkDefault true;
    systemd.services.thermald.serviceConfig.ExecCondition =
      lib.mkIf (config.services.thermald.enable && !config.services.thermald.ignoreCpuidCheck)
        "${lib.getExe pkgs.gnugrep} -q '^vendor_id[[:space:]]*:[[:space:]]*GenuineIntel$' /proc/cpuinfo";
  })
])
