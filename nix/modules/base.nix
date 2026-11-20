{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
in
lib.mkIf cfg.enable {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.description;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
  };

  services.fstrim.enable = true;
  services.fwupd.enable = true;
  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    git curl wget jq ripgrep fd btop fastfetch unzip
  ];
}
