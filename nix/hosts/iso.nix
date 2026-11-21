{ config, disko, lib, modulesPath, oninixSource, pkgs, ... }:
let
  installer = pkgs.callPackage ../installer {
    disko = disko.packages.${pkgs.stdenv.hostPlatform.system}.disko;
    source = oninixSource;
  };
  installerEntry = pkgs.makeDesktopItem {
    name = "oninix-installer";
    desktopName = "Install OniNix";
    comment = "Install OniNix to a local disk";
    exec = ''${lib.getExe pkgs.kitty} --title "Install OniNix" --hold oninix-installer'';
    icon = "system-software-install";
    categories = [ "System" ];
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-base.nix" ];

  oninix = {
    enable = true;
    user = {
      name = "nixos";
      description = "OniNix Live";
    };
  };

  system.nixos.distroName = "OniNix";
  networking.hostName = "oninix-live";
  services.displayManager.autoLogin.user = "nixos";
  services.udisks2.enable = true;

  environment.systemPackages = [ installerEntry installer ];

  image.baseName = lib.mkForce "oninix-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}";
  isoImage = {
    volumeID = "oninix-${config.system.nixos.release}-${pkgs.stdenv.hostPlatform.uname.processor}";
    grubTheme = config.boot.loader.grub.theme;
    squashfsCompression = "zstd -Xcompression-level 15";
  };

  boot.supportedFilesystems.zfs = lib.mkForce false;

  system.installer.channel.enable = false;
  documentation.enable = lib.mkForce false;
  documentation.nixos.enable = lib.mkForce false;
  nixpkgs.overlays = [ (_final: prev: {
    speechd = prev.speechd.override {
      espeak = prev.espeak.override { mbrolaSupport = false; };
    };
  }) ];
  nix.settings.auto-optimise-store = lib.mkForce false;
  services.fwupd.enable = lib.mkForce false;
  services.fstrim.enable = lib.mkForce false;
  systemd.user.timers.oninix-update-check.enable = false;
}
