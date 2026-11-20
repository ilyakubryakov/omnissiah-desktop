{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  share = pkgs.callPackage ../pkgs/share.nix { };
  session = pkgs.writeTextFile {
    name = "oninix-uwsm";
    destination = "/share/wayland-sessions/oninix-uwsm.desktop";
    text = ''
      [Desktop Entry]
      Name=OniNix (UWSM)
      Comment=Hyprland with the OniNix desktop
      Exec=${lib.getExe config.programs.uwsm.package} start -F -e -D Hyprland -- /run/current-system/sw/bin/start-hyprland -- --config ${share}/share/oninix/hypr/hyprland.lua
      Type=Application
      DesktopNames=Hyprland
    '';
    derivationArgs.passthru.providedSessions = [ "oninix-uwsm" ];
  };
in
lib.mkIf cfg.enable {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  services.displayManager.sessionPackages = [ session ];
  environment.pathsToLink = [ "/share/oninix" ];
  environment.sessionVariables.ONINIX_SHARE = "/run/current-system/sw/share/oninix";
  programs.hyprlock.enable = true;
  systemd.user.services.hypridle = {
    environment.ONINIX_LAPTOP = if cfg.hardware.laptop then "1" else "0";
    path = [ config.services.hypridle.package pkgs.python3 pkgs.util-linux "/run/current-system/sw" ];
    serviceConfig.ExecStart = [ "" "${share}/share/oninix/hypr/scripts/idle.sh" ];
  };
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.mime.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";

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
    session
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
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.breeze
    kdePackages.breeze-icons
    papirus-icon-theme
    qt6Packages.qt6ct
  ];
}
