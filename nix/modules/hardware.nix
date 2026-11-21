{ config, lib, pkgs, ... }:
let
  cfg = config.oninix.hardware;
in
lib.mkIf config.oninix.enable (lib.mkMerge [
  {
    hardware.graphics.enable = true;
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  }

  (lib.mkIf (cfg.gpu == "nvidia") {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      open = lib.mkDefault true;
      videoAcceleration = lib.mkDefault true;
      modesetting.enable = true;
      powerManagement.enable = lib.mkDefault true;
    };
    environment.sessionVariables.NVD_BACKEND = lib.mkDefault "direct";
    environment.systemPackages = with pkgs; [ vulkan-tools libva-utils ];
    environment.etc."nvidia/nvidia-application-profiles-rc.d/50-oninix-desktop.json".text = builtins.toJSON {
      profiles = [{
        name = "OniNixDesktopBuffers";
        settings = [ "GLVidHeapReuseRatio" 0 ];
      }];
      rules = map (name: {
        pattern = { feature = "procname"; matches = name; };
        profile = "OniNixDesktopBuffers";
      }) [ ".Hyprland-wrapped" ".quickshell-wrapped" ".kitty-wrapped" ];
    };
  })

  (lib.mkIf (cfg.gpu == "amd") {
    services.xserver.videoDrivers = [ "amdgpu" ];
    environment.systemPackages = with pkgs; [ vulkan-tools libva-utils ];
  })

  (lib.mkIf cfg.laptop {
    services.logind.settings.Login.HandleLidSwitch = "suspend";
    services.thermald.enable = lib.mkDefault true;
    systemd.services.thermald.serviceConfig.ExecCondition =
      lib.mkIf (config.services.thermald.enable && !config.services.thermald.ignoreCpuidCheck)
        "${lib.getExe pkgs.gnugrep} -q '^vendor_id[[:space:]]*:[[:space:]]*GenuineIntel$' /proc/cpuinfo";
  })
])
