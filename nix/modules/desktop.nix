{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  share = pkgs.callPackage ../pkgs/share.nix { };
  autoLogin = config.services.displayManager.autoLogin;
  keyboardLayout = config.services.xserver.xkb.layout;
  checkGraphics = pkgs.writeShellScript "oninix-check-graphics" ''
    for attempt in 1 2 3 4 5 6; do
      for card in /dev/dri/card[0-9]*; do
        if [ -c "$card" ]; then exit 0; fi
      done
      if [ "$attempt" -lt 6 ]; then sleep 1; fi
    done
    message="OniNix: No DRM graphics device found. Use a text console (Ctrl+Alt+F2) or SSH if configured."
    if [ -x /run/current-system/sw/bin/oninix-installer ]; then
      message="$message Run oninix-installer to install OniNix."
    fi
    printf '%s\n' "$message" | tee /dev/console
    exit 1
  '';
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
    [ session greeter.iconTheme.package greeter.cursorTheme.package pkgs.glycin-loaders pkgs.shared-mime-info ]
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
  environment.pathsToLink = [ "/share/oninix" "/share/hunspell" ];
  environment.sessionVariables = {
    ONINIX_SHARE = "/run/current-system/sw/share/oninix";
    DICPATH = "/run/current-system/sw/share/hunspell";
    ONINIX_XKB_LAYOUT = keyboardLayout;
    ONINIX_LAPTOP = if cfg.hardware.laptop then "1" else "0";
  };
  programs.hyprlock.enable = true;
  systemd.user.services.hypridle = {
    environment.ONINIX_LAPTOP = if cfg.hardware.laptop then "1" else "0";
    path = [ config.services.hypridle.package pkgs.python3 pkgs.util-linux "/run/current-system/sw" ];
    serviceConfig.ExecStart = [ "" "${share}/share/oninix/hypr/scripts/idle.sh" ];
  };
  qt = {
    enable = lib.mkDefault true;
    platformTheme = lib.mkDefault "qt5ct";
    style = lib.mkDefault "breeze";
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
    "PATH=${lib.makeBinPath [ pkgs.bubblewrap ]}:$PATH"
    "GTK_USE_PORTAL=0 GDK_DEBUG=no-portals GSK_RENDERER=cairo LIBSEAT_BACKEND=logind XKB_DEFAULT_OPTIONS=grp:caps_toggle"
    "XKB_DEFAULT_LAYOUT=${lib.escapeShellArg keyboardLayout}"
    "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe cage}"
    "${lib.escapeShellArgs greeter.cageArgs} -- ${lib.getExe greeter.package}"
  ];
  services.greetd.restart = !autoLogin.enable;
  systemd.services.greetd = {
    after = [ "systemd-udev-trigger.service" ];
    serviceConfig = {
      ExecCondition = checkGraphics;
      RestartSec = "1s";
    };
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
  systemd.user.services.oninix-notebook-reminders = {
    description = "Deliver OniNix Notebook reminders and timers";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = [ pkgs.libnotify ];
    serviceConfig = {
      ExecStart = "${share}/bin/oninix-notebook --watch";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
  systemd.user.services.caldash = {
    description = "Sync OniNix calendars";
    partOf = [ "graphical-session.target" ];
    path = [ "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${share}/bin/oninix-calendar --sync";
    };
  };
  systemd.user.timers.caldash = {
    description = "Refresh OniNix calendars";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "5s";
      OnUnitActiveSec = "10min";
    };
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
    alsa = {
      enable = true;
      support32Bit = lib.mkDefault pkgs.stdenv.hostPlatform.isx86_64;
    };
    pulse.enable = true;
  };

  security.polkit.enable = true;
  systemd.user.services.oninix-polkit-agent = {
    description = "OniNix desktop authorization prompts";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "wayland-session-waitenv.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
  };
  services.printing.enable = lib.mkDefault true;
  programs.system-config-printer.enable = lib.mkDefault config.services.printing.enable;
  hardware.sane = {
    enable = lib.mkDefault true;
    extraBackends = [ pkgs.sane-airscan ];
  };
  services.udisks2.enable = lib.mkDefault true;
  services.gvfs.enable = lib.mkDefault true;
  systemd.user.services.oninix-automount = lib.mkIf (cfg.hardware.autoMount && config.services.udisks2.enable) {
    description = "Mount removable media in the OniNix session";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "wayland-session-waitenv.service" ];
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.udiskie} --automount --no-notify --no-tray";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
  services.flatpak.enable = lib.mkDefault true;
  programs.chromium = {
    enable = true;
    extraOptsRecommended = {
      SpellcheckEnabled = true;
      SpellcheckLanguage = [ "en-US" "ru" ];
    };
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  fonts = {
    packages = with pkgs; [
      inter
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      carlito
      caladea
      liberation_ttf
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Inter" "Noto Sans" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

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
    hyprpicker
    (tesseract.override { enableLanguages = [ "eng" "rus" ]; })
    zbar
    brightnessctl
    playerctl
    alsa-utils
    pipewire.jack
    pavucontrol
    hunspell
    hunspellDicts.en_US
    hunspellDicts.ru_RU
    hyphenDicts.en_US
    networkmanagerapplet
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.breeze
    kdePackages.breeze-icons
    kdePackages.breeze-gtk
    kdePackages.kconfig
    papirus-icon-theme
    rofi
    libnotify
    glib
    cava
    swappy
    wf-recorder
  ] ++ lib.optional config.hardware.sane.enable pkgs.kdePackages.skanpage;
}
