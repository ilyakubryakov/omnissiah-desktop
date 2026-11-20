{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  share = pkgs.callPackage ../pkgs/share.nix { };
  autoLogin = config.services.displayManager.autoLogin;
  keyboardLayout = config.services.xserver.xkb.layout;
  sessionCommand = "${lib.getExe config.programs.uwsm.package} start -F -e -D Hyprland -- /run/current-system/sw/bin/start-hyprland -- --config ${share}/share/oninix/hypr/hyprland.lua";
  session = pkgs.writeTextFile {
    name = "oninix-uwsm";
    destination = "/share/wayland-sessions/oninix-uwsm.desktop";
    text = ''
      [Desktop Entry]
      Name=OniNix (UWSM)
      Comment=Hyprland with the OniNix desktop
      Exec=${sessionCommand}
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
  palette = builtins.fromTOML (builtins.readFile ../../desktop/themes/omnissiah/colors.toml);
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
  services.xserver.xkb.layout = lib.mkDefault "us,ru";
  environment.pathsToLink = [ "/share/oninix" ];
  environment.sessionVariables = {
    ONINIX_SHARE = "/run/current-system/sw/share/oninix";
    ONINIX_XKB_LAYOUT = keyboardLayout;
    ONINIX_LAPTOP = if cfg.hardware.laptop then "1" else "0";
  };
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
  services.greetd.settings.initial_session = lib.mkIf autoLogin.enable {
    command = sessionCommand;
    user = autoLogin.user;
  };
  services.greetd.settings.default_session.command = lib.concatStringsSep " " [
    "${lib.getExe' pkgs.coreutils "env"} XDG_DATA_DIRS=${greeterDataDirs}"
    "GSK_RENDERER=cairo LIBSEAT_BACKEND=logind XKB_DEFAULT_OPTIONS=grp:caps_toggle"
    "XKB_DEFAULT_LAYOUT=${lib.escapeShellArg keyboardLayout}"
    "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe cage}"
    "${lib.escapeShellArgs greeter.cageArgs} -- ${lib.getExe greeter.package}"
  ];
  systemd.services.greetd.serviceConfig = {
    Restart = lib.mkForce (if autoLogin.enable then "no" else "always");
    RestartSec = "1s";
  };

  systemd.user.services.oninix-panel = {
    description = "OniNix panels, Control Station and desktop overlays";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wants = [ "oninix-theme.service" ];
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    serviceConfig = {
      ExecStart = "${share}/bin/oninix-shell -n";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
  systemd.user.services.oninix-theme = {
    description = "Apply the OniNix desktop palette";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      oninix-theme
      oninix-theme-schedule
    '';
  };
  systemd.user.services.oninix-wallpaper = {
    description = "OniNix wallpaper service";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    script = ''
      image=$(${share}/bin/oninix-theme wallpaper-path)
      exec ${lib.getExe pkgs.swaybg} -i "$image" -m fill
    '';
  };
  systemd.user.services.oninix-keep-awake = {
    description = "Suspend automatic idle actions while the desktop is in use";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${lib.getExe' pkgs.systemd "systemd-inhibit"} --what=idle --who=OniNix --why=Keep-awake ${lib.getExe' pkgs.coreutils "sleep"} infinity";
  };
  systemd.user.services.oninix-theme-schedule = {
    description = "Apply scheduled OniNix palette and night light";
    after = [ "oninix-theme.service" ];
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${share}/bin/oninix-theme-schedule";
    };
  };
  systemd.user.timers.oninix-theme-schedule = {
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "1min";
      OnUnitActiveSec = "1min";
      AccuracySec = "1s";
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
