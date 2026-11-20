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
  greeter = config.services.displayManager.regreet;
  greeterDataDirs = lib.makeSearchPath "share" (
    [ session greeter.iconTheme.package greeter.cursorTheme.package ]
    ++ lib.optional (greeter.theme.package != null) greeter.theme.package
  );
  palette = builtins.fromTOML (builtins.readFile ../../themes/omnissiah/colors.toml);
  paletteNames = builtins.attrNames palette;
  greeterCss = lib.replaceStrings
    (map (name: "@${name}@") paletteNames)
    (map (name: palette.${name}) paletteNames)
    (builtins.readFile ../greeter/style.css.in);
  cage = pkgs.cage.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../greeter/cage-last-output-teardown.patch ];
  });
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

  services.displayManager.regreet = {
    enable = true;
    font = { package = pkgs.inter; name = "Inter"; size = 16; };
    iconTheme = { package = pkgs.papirus-icon-theme; name = "Papirus-Dark"; };
    cageArgs = [ "-s" "-d" "-m" "last" ];
    extraCss = greeterCss;
    settings = {
      skip_selection = false;
      background = { path = "${../boot/mechanicus-dark.png}"; fit = "Cover"; };
      GTK.application_prefer_dark_theme = true;
      appearance.greeting_msg = "ONINIX · Communing with the machine spirit";
      widget.clock = { format = "%H:%M · %A, %e %B"; resolution = "1s"; };
    };
  };
  services.greetd.settings.default_session.command = lib.concatStringsSep " " [
    "${lib.getExe' pkgs.coreutils "env"} XDG_DATA_DIRS=${greeterDataDirs}"
    "GSK_RENDERER=cairo LIBSEAT_BACKEND=logind XKB_DEFAULT_OPTIONS=grp:caps_toggle"
    "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe cage}"
    "${lib.escapeShellArgs greeter.cageArgs} -- ${lib.getExe greeter.package}"
  ];
  systemd.services.greetd.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = "1s";
  };

  systemd.user.services.oninix-panel = {
    description = "OniNix panels, Control Station and desktop overlays";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    serviceConfig = {
      ExecStart = "${share}/bin/oninix-shell -n";
      Restart = "on-failure";
      RestartSec = 2;
    };
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
    rofi
    libnotify
    glib
    cava
    swappy
    jq
  ];
}
