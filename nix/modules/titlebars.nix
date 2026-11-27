{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  hyprland = config.programs.hyprland.package;
  plugin = pkgs.callPackage ../pkgs/hyprland-titlebars.nix { inherit hyprland; };
  key = builtins.unsafeDiscardStringContext (builtins.baseNameOf "${hyprland}");
  drv = builtins.unsafeDiscardStringContext plugin.drvPath;
  recipe = (pkgs.callPackage ../pkgs/deferred-derivation.nix { nix = config.nix.package; }) plugin;
  out = builtins.unsafeDiscardStringContext plugin.outPath;
in
{
  options.oninix.titlebars.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Window titlebars on floating workspaces, from the Omarchy titlebars plugin for Hyprland.
      The system carries only the plugin's derivation: oninix-titlebars-build builds it after
      activation against the installed Hyprland, so a plugin that stops building never blocks an
      update. The session loads it only when it was built for the running Hyprland binary.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.titlebars.enable) {
    environment.etc."oninix/titlebars-enabled".text = key + "\n" + out + "/lib/omarchy-hyprland-titlebars/titlebars.so\n";
    systemd.services.oninix-titlebars-build = {
      description = "Build the Hyprland titlebars plugin for the installed Hyprland";
      wantedBy = [ "multi-user.target" ];
      after = [ "nix-daemon.socket" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [ recipe ];
      path = [ config.nix.package pkgs.coreutils pkgs.gzip ];
      serviceConfig = {
        Type = "exec";
        RemainAfterExit = true;
        Nice = 15;
        IOSchedulingClass = "idle";
      };
      script = ''
        roots=/nix/var/nix/gcroots/oninix-titlebars
        mkdir -p "$roots"
        if ! nix-store --check-validity ${drv} 2>/dev/null; then
          gzip -dc ${recipe} | nix-store --import >/dev/null
        fi
        timeout 1h nix-store --realise ${drv} --add-root "$roots/${key}" >/dev/null
        test -f "$roots/${key}/lib/omarchy-hyprland-titlebars/titlebars.so"
        touch -h "$roots/${key}"
        ls -1t "$roots" | tail -n +4 | while read -r old; do rm -f "$roots/$old"; done
      '';
    };
  };
}
