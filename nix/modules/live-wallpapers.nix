{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  share = pkgs.callPackage ../pkgs/share.nix { };
  linux-wallpaperengine = pkgs.linux-wallpaperengine.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../pkgs/linux-wallpaperengine-align.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/WallpaperEngine/Render/Objects/CText.cpp \
        --replace-fail /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf
      substituteInPlace src/WallpaperEngine/Application/ApplicationContext.cpp \
        --replace-fail "(this->settings.screenshot.delay, 5)" "(this->settings.screenshot.delay, 300)"
    '';
  });
in
{
  options.oninix.liveWallpapers.enable = lib.mkOption {
    type = lib.types.bool;
    default = cfg.features.gaming;
    defaultText = lib.literalExpression "config.oninix.features.gaming";
    description = ''
      Live wallpapers from Wallpaper Engine's Steam Workshop on the main display: videos through
      mpvpaper, scenes and web items through linux-wallpaperengine. Needs Steam with Wallpaper
      Engine installed. Paused under maximized, fullscreen or covering windows, unloaded in Game
      mode, and yields video memory to other apps by showing the item's own still.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.liveWallpapers.enable) {
    environment.systemPackages = [ pkgs.mpvpaper linux-wallpaperengine pkgs.bubblewrap pkgs.grim pkgs.ffmpeg-headless ];
    systemd.user.services.oninix-livewall = {
      description = "Live wallpaper renderer and pause controller";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" "oninix-wallpaper.service" ];
      path = [ "/run/wrappers" "/run/current-system/sw" ];
      serviceConfig = {
        ExecStart = "${share}/bin/oninix-livewall daemon";
        Restart = "on-failure";
        RestartSec = 5;
        KillMode = "mixed";
      };
    };
  };
}
