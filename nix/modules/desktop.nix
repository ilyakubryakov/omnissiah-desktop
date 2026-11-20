{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  share = pkgs.callPackage ../pkgs/share.nix { };
in
lib.mkIf cfg.enable {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.uwsm.waylandCompositors.oninix = {
    prettyName = "OniNix";
    comment = "Hyprland with the OniNix desktop";
    binPath = "/run/current-system/sw/bin/Hyprland";
    extraArgs = [ "--config" "${share}/share/oninix/hypr/hyprland.lua" ];
  };
  environment.pathsToLink = [ "/share/oninix" ];
  environment.sessionVariables.ONINIX_SHARE = "/run/current-system/sw/share/oninix";
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.greetd = {
    enable = true;
    settings.default_session.command =
      "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start oninix-uwsm.desktop'";
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    share
    quickshell
    hyprpaper
    hyprsunset
    kitty
    fuzzel
    mako
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    playerctl
    pavucontrol
    networkmanagerapplet
    kdePackages.breeze
    kdePackages.breeze-icons
    papirus-icon-theme
    qt6Packages.qt6ct
  ];
}
