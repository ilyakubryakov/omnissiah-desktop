{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
  scx = config.services.scx-loader;
  scxState = pkgs.writeShellScript "oninix-scx-state" ''
    set -eu
    prop() { ${pkgs.systemd}/bin/busctl --system get-property org.scx.Loader /org/scx/Loader org.scx.Loader "$1"; }
    case "$1" in auto) mode=0 ;; gaming) mode=1 ;; *) exit 2 ;; esac
    [ "$(prop CurrentScheduler)" = 's "scx_lavd"' ] || exit 1
    [ "$(prop CurrentSchedulerArgs)" = 'as 0' ] || exit 1
    [ "$(prop SchedulerMode)" = "u $mode" ]
  '';
  ollama =
    if cfg.hardware.gpu == "none" then pkgs.ollama
    else pkgs.ollama-vulkan;
in
lib.mkIf cfg.enable (lib.mkMerge [
  (lib.mkIf cfg.features.gaming {
    nixpkgs.config.problems.handlers."gtk+".broken = "warn";
    programs.steam = {
      enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      extraPackages = with pkgs; [ mangohud gamescope ];
    };
    programs.gamescope.enable = true;
    programs.gamemode = {
      enable = true;
      settings.general.renice = 10;
    };
    users.users.${cfg.user.name}.extraGroups = [ "gamemode" ];
    boot.kernelModules = [ "ntsync" ];
    environment.systemPackages = with pkgs; [ mangohud protonplus protontricks lutris heroic umu-launcher ];

    services.scx-loader = {
      enable = true;
      config = {
        default_sched = "scx_lavd";
        default_mode = "Auto";
        scheds.scx_lavd = {
          auto_mode = [ ];
          gaming_mode = [ "--performance" ];
        };
      };
    };
    systemd.services.scx_loader.unitConfig.ConditionPathExists = "/sys/kernel/sched_ext/state";
    systemd.services.oninix-game-performance = {
      description = "LAVD performance profile while Game mode is on";
      after = [ "scx_loader.service" ];
      path = [ pkgs.systemd scx.package ];
      unitConfig = {
        ConditionPathExists = "/sys/kernel/sched_ext/state";
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecCondition = "${scxState} auto";
        ExecStart = pkgs.writeShellScript "oninix-game-performance-start" ''
          set -eu
          if ! scxctl switch --sched scx_lavd --mode gaming; then
            scxctl restore || true
            exit 1
          fi
          ${scxState} gaming
        '';
        ExecStopPost = pkgs.writeShellScript "oninix-game-performance-stop" ''
          set -eu
          ${scxState} gaming || exit 0
          scxctl switch --sched scx_lavd --mode auto
        '';
      };
    };
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (subject.user != ${builtins.toJSON cfg.user.name} || !subject.local || !subject.active) return;
        if (action.id != "org.freedesktop.systemd1.manage-units") return;
        const allowed = ${builtins.toJSON ([ "oninix-game-performance.service" ] ++ lib.optional cfg.features.ai "ollama.service")};
        if (allowed.indexOf(action.lookup("unit")) < 0) return;
        if (["start", "stop"].indexOf(action.lookup("verb")) >= 0) return polkit.Result.YES;
      });
    '';
  })

  (lib.mkIf cfg.features.coding {
    programs.git.enable = true;
    programs.direnv.enable = true;
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [ stdenv.cc.cc zlib openssl ];
    };
    virtualisation.docker.enable = true;
    users.users.${cfg.user.name}.extraGroups = [ "docker" ];
    environment.sessionVariables = {
      UV_PYTHON_DOWNLOADS = "never";
      UV_PYTHON_PREFERENCE = "only-system";
    };
    environment.systemPackages = with pkgs; [
      vscode neovim gh git-lfs lazygit
      gcc gnumake cmake pkg-config
      python3 uv ruff
      nodejs
      rustup go
      shellcheck nixfmt nil
    ];
  })

  (lib.mkIf cfg.features.music {
    services.pipewire.extraConfig.pipewire."92-oninix-low-latency" = {
      "context.properties"."default.clock.min-quantum" = 64;
      "context.properties.rules" = [
        {
          matches = [ { "cpu.vm.name" = "!null"; } ];
          actions.update-props."default.clock.min-quantum" = 64;
        }
      ];
    };
    users.users.${cfg.user.name}.extraGroups = [ "audio" ];
    environment.systemPackages = with pkgs; [
      (reaper.override { jackLibrary = config.services.pipewire.package.jack; })
      qpwgraph
      pwvucontrol
      alsa-utils
      alsa-scarlett-gui
    ];
  })

  (lib.mkIf cfg.features.ai {
    environment.systemPackages = [ pkgs.claude-code pkgs.codex ollama ];
    services.ollama = {
      enable = true;
      package = ollama;
      host = "127.0.0.1";
    };
  })
])
