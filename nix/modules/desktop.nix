{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
in
lib.mkIf cfg.enable {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.greetd = {
    enable = true;
    settings.default_session.command =
      "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
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
