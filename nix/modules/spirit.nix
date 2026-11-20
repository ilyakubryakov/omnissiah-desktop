{ config, lib, pkgs, ... }:
lib.mkIf config.oninix.enable {
  environment.systemPackages = with pkgs; [ bubblewrap gum nvd ];
}
