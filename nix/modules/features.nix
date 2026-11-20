{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
in
lib.mkIf cfg.enable (lib.mkMerge [
  (lib.mkIf cfg.features.gaming {
    programs.steam.enable = true;
    programs.gamemode.enable = true;
    programs.gamescope.enable = true;
    users.users.${cfg.user.name}.extraGroups = [ "gamemode" ];
    environment.systemPackages = with pkgs; [ mangohud protonplus lutris heroic ];
  })

  (lib.mkIf cfg.features.coding {
    programs.git.enable = true;
    environment.systemPackages = with pkgs; [ neovim vscode gcc gnumake python3 nodejs uv direnv ];
  })

  (lib.mkIf cfg.features.music {
    environment.systemPackages = with pkgs; [ reaper qpwgraph ];
  })

  (lib.mkIf cfg.features.ai {
    environment.systemPackages = with pkgs; [ claude-code codex ];
  })
])
