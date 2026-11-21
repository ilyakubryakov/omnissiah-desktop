{ config, lib, pkgs, ... }:
let
  cfg = config.oninix;
in
lib.mkIf cfg.enable {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.description;
    shell = lib.mkOverride 900 pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellInit = ''
      if [[ -o interactive ]]; then
        function zsh-newuser-install() { unfunction zsh-newuser-install; }
      fi
    '';
    interactiveShellInit = ''
      source /etc/oninix/zshrc
    '';
  };
  programs.zoxide.enable = true;

  boot.kernel.sysctl."kernel.sysrq" = lib.mkDefault 176;

  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.smartd.enable = lib.mkDefault true;
  systemd.services.smartd.unitConfig.ConditionVirtualization =
    lib.mkIf config.services.smartd.enable false;
  services.journald.settings.Journal.SystemMaxUse = lib.mkDefault "2G";
  systemd.coredump.enable = lib.mkDefault true;
  zramSwap.enable = true;

  environment.etc = {
    "oninix/zshrc".source = ../../desktop/terminal/zshrc;
    "xdg/fastfetch/config.jsonc".source = ../../desktop/fastfetch/config.jsonc;
    "xdg/kitty/kitty.conf".source = ../../desktop/terminal/kitty.conf;
  };

  environment.systemPackages = with pkgs; [
    google-chrome
    git curl wget jq ripgrep fd btop fastfetch unzip
    rsync file p7zip unrar zstd htop
    pciutils usbutils lm_sensors nvme-cli smartmontools
    tmux mc starship fzf bat eza delta ncdu tree
  ];
}
