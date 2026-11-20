{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  gpu = cfg.hardware.gpu;
  acceleration = lib.optionalAttrs (gpu != "none") {
    cudaSupport = gpu == "nvidia";
    vulkanSupport = gpu == "amd" || gpu == "intel";
  };
  path = [ "/run/wrappers" "/run/current-system/sw" ];
in
{
  options.oninix.voice.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Hold-to-talk dictation and voice for the machine spirit, sized to the hardware by oninix-voice-profile.";
  };

  config = lib.mkIf (cfg.enable && cfg.voice.enable) {
    environment.systemPackages = with pkgs; [
      (whisper-cpp.override acceleration)
      (llama-cpp.override acceleration)
      ffmpeg-headless
      wtype
      pciutils
    ];

    systemd.user.services.oninix-voice-profile = {
      description = "Pick the Whisper model this machine can run live";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" "network-online.target" ];
      unitConfig.ConditionPathExists = "!%S/oninix/voice.json";
      inherit path;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/run/current-system/sw/bin/oninix-voice-profile";
        Nice = 10;
      };
    };

    systemd.user.services.oninix-dictation = {
      description = "Hold-to-talk local Whisper dictation";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "pipewire.service" "graphical-session.target" ];
      inherit path;
      serviceConfig = {
        ExecStart = "/run/current-system/sw/bin/oninix-dictation --serve";
        UMask = "0077";
        NoNewPrivileges = true;
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
