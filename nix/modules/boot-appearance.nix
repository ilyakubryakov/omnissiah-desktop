{ config, lib, pkgs, ... }:
let
  artwork = pkgs.runCommand "oninix-boot-artwork" {
    nativeBuildInputs = [ pkgs.python3 pkgs.grub2 ];
  } ''
    mkdir -p "$out/grub" "$out/share/plymouth/themes/oninix"
    cp ${../boot/mechanicus-dark.png} "$out/grub/background.png"
    cp ${../boot/mechanicus.png} "$out/share/plymouth/themes/oninix/mechanicus.png"
    python3 ${../boot/render.py} ${../../themes/omnissiah/colors.toml} ${../boot} "$out"
    grub-mkfont --name="OniNix Sans" --size=24 --output="$out/grub/oninix.pf2" \
      ${pkgs.dejavu_fonts.minimal}/share/fonts/truetype/DejaVuSans.ttf
  '';
in
lib.mkIf config.oninix.enable {
  boot.loader = {
    timeout = lib.mkDefault 5;
    efi.canTouchEfiVariables = lib.mkDefault true;
    grub = {
      enable = lib.mkDefault true;
      efiSupport = lib.mkDefault true;
      device = lib.mkDefault "nodev";
      configurationLimit = lib.mkDefault 20;
      theme = "${artwork}/grub";
      splashImage = null;
      font = "${artwork}/grub/oninix.pf2";
    };
  };
  boot.plymouth = {
    enable = lib.mkDefault true;
    theme = lib.mkDefault "oninix";
    themePackages = [ artwork ];
  };
  boot.consoleLogLevel = lib.mkDefault 3;
  boot.kernelParams = [ "quiet" "udev.log_level=3" "rd.udev.log_level=3" ];
}
