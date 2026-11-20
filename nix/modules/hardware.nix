{ config, lib, ... }:
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
  })
])
