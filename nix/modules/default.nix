{ lib, ... }:
let
  feature = description: lib.mkEnableOption description;
in
{
  imports = [
    ./base.nix
    ./desktop.nix
    ./hardware.nix
    ./features.nix
  ];

  options.oninix = {
    enable = lib.mkEnableOption "the OniNix distribution";

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Login name of the main user.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Full name shown on the greeter.";
      };
    };

    hardware = {
      gpu = lib.mkOption {
        type = lib.types.enum [ "nvidia" "amd" "intel" "none" ];
        default = "none";
        description = "Graphics driver profile, detected by the installer.";
      };
      laptop = lib.mkEnableOption "laptop power, lid and backlight handling";
    };

    features = {
      gaming = feature "Steam, Proton, Game mode and launchers";
      coding = feature "editors, language toolchains and developer tools";
      music = feature "low-latency audio and a DAW";
      ai = feature "AI agents and accounts (Claude, Codex, local models)";
    };
  };
}
