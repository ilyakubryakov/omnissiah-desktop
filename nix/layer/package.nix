{ pkgs, lib, buildEnv, callPackage, makeWrapper, runCommand, writeText, extraPackages ? [ ] }:
let
  share = callPackage ../pkgs/share.nix { softwareRendering = true; };
  fonts = with pkgs; [ inter nerd-fonts.jetbrains-mono nerd-fonts.symbols-only noto-fonts-color-emoji ];
  fontConfig = writeText "oninix-layer-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include>/etc/fonts/fonts.conf</include>
      ${lib.concatMapStringsSep "\n" (font: "<dir>${font}/share/fonts</dir>") fonts}
    </fontconfig>
  '';
  terminal = pkgs.symlinkJoin {
    name = "oninix-layer-kitty";
    paths = [ pkgs.kitty ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/kitty" \
        --set-default __EGL_VENDOR_LIBRARY_FILENAMES "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json" \
        --set-default LIBGL_DRIVERS_PATH "${pkgs.mesa}/lib/dri" \
        --set-default LIBGL_ALWAYS_SOFTWARE 1
    '';
  };
  launch = "%S/oninix/layer/profile/bin/oninix-layer-run";
  service = description: command: extra: ''
    [Unit]
    Description=${description}
    PartOf=oninix-layer.target
    After=graphical-session.target

    [Service]
    ExecStart=${launch} ${command}
    ${extra}
  '';
  units = {
    "oninix-layer.target" = ''
      [Unit]
      Description=OniNix desktop layer
      PartOf=graphical-session.target
      Wants=oninix-theme.service oninix-panel.service oninix-wallpaper.service oninix-notifications.service
      Wants=oninix-idle.service oninix-dictation.service oninix-voice-profile.service oninix-notebook-reminders.service
      Wants=oninix-update-check.timer oninix-theme-schedule.timer caldash.timer
    '';
    "oninix-panel.service" = service "OniNix panels and Control Station" "oninix-shell -n" ''
      Restart=on-failure
      RestartSec=2
    '';
    "oninix-theme.service" = service "Apply the OniNix desktop palette" "oninix-theme" ''
      Type=oneshot
      RemainAfterExit=yes
    '';
    "oninix-wallpaper.service" = ''
      [Unit]
      Description=OniNix wallpaper
      After=oninix-theme.service
      PartOf=oninix-layer.target

      [Service]
      ExecStart=${launch} bash -c 'exec swaybg -i "$(oninix-theme wallpaper-path)" -m fill'
    '';
    "oninix-notifications.service" = ''
      [Unit]
      Description=OniNix notifications
      After=oninix-theme.service
      PartOf=oninix-layer.target

      [Service]
      ExecStart=${launch} mako --config=%S/theme/mako.conf
    '';
    "oninix-idle.service" = service "OniNix idle and lock actions" "sh -c 'exec \"$$ONINIX_SHARE/hypr/scripts/idle.sh\"'" "";
    "oninix-dictation.service" = service "Hold-to-talk OniNix dictation" "oninix-dictation --serve" ''
      UMask=0077
      NoNewPrivileges=yes
      Restart=on-failure
      RestartSec=3
    '';
    "oninix-voice-profile.service" = ''
      [Unit]
      Description=Pick a Whisper model for OniNix
      ConditionPathExists=!%S/oninix/voice.json
      PartOf=oninix-layer.target

      [Service]
      Type=oneshot
      ExecStart=${launch} oninix-voice-profile
      Nice=10
    '';
    "oninix-update-check.service" = service "Check for OniNix layer updates" "oninix-maintenance daily" ''
      Type=oneshot
      Nice=15
      IOSchedulingClass=idle
    '';
    "oninix-update-check.timer" = ''
      [Unit]
      Description=Check for OniNix layer updates
      PartOf=oninix-layer.target

      [Timer]
      OnActiveSec=15min
      OnUnitActiveSec=1h
      RandomizedDelaySec=10min
    '';
    "oninix-notebook-reminders.service" = service "Deliver OniNix Notebook reminders and timers" "oninix-notebook --watch" ''
      Restart=on-failure
      RestartSec=2
    '';
    "caldash.service" = service "Sync OniNix calendars" "oninix-calendar --sync" "Type=oneshot";
    "caldash.timer" = ''
      [Unit]
      Description=Refresh OniNix calendars
      PartOf=oninix-layer.target

      [Timer]
      OnActiveSec=5s
      OnUnitActiveSec=10min
    '';
    "oninix-theme-schedule.service" = service "Apply scheduled OniNix palette and night light" "oninix-theme-schedule" "Type=oneshot";
    "oninix-theme-schedule.timer" = ''
      [Unit]
      Description=Apply scheduled OniNix palette and night light
      PartOf=oninix-layer.target

      [Timer]
      OnActiveSec=1min
      OnUnitActiveSec=1min
      AccuracySec=1s
    '';
  };
  idleOverride = writeText "oninix-layer-idle.conf" ''
    [Unit]
    ConditionEnvironment=!ONINIX_LAYER_DIRECT
  '';
  integration = runCommand "oninix-layer-integration" { } ''
    mkdir -p "$out/bin" "$out/share/oninix-layer/systemd/user"
    cp ${./oninix-layer-session} "$out/bin/oninix-layer-session"
    cp ${./oninix-layer-compositor} "$out/bin/oninix-layer-compositor"
    cp ${./oninix-layer-ready} "$out/bin/oninix-layer-ready"
    cp ${./oninix-layer-run} "$out/bin/oninix-layer-run"
    cp ${../../oninix-install} "$out/bin/oninix-install"
    cp ${./environment} "$out/share/oninix-layer/environment"
    ln -s ${idleOverride} "$out/share/oninix-layer/hypridle.conf"
    ln -s ${fontConfig} "$out/share/oninix-layer/fonts.conf"
    chmod +x "$out/bin/"*
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (file: content:
      "cp ${writeText file content} \"$out/share/oninix-layer/systemd/user/${file}\""
    ) units)}
  '';
in
buildEnv {
  name = "oninix-layer";
  paths = [ share terminal integration ] ++ (with pkgs; [
    quickshell fuzzel rofi mako swaybg wl-clipboard cliphist grim slurp swappy wf-recorder
    hyprpicker (tesseract.override { enableLanguages = [ "eng" "rus" ]; }) zbar
    brightnessctl playerctl pavucontrol kdePackages.dolphin papirus-icon-theme
    libnotify glib jq bubblewrap gum nvd wtype pciutils whisper-cpp ffmpeg-headless btop
  ]) ++ extraPackages;
  pathsToLink = [ "/bin" "/share" ];
}
