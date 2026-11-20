{
  description = "OniNix: a Hyprland desktop distribution on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
    in
    {
      nixosModules.default = import ./nix/modules;
      nixosModules.oninix = self.nixosModules.default;

      templates.default = {
        path = ./nix/template;
        description = "An OniNix machine";
      };

      nixosConfigurations.demo = lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          self.nixosModules.default
          ./nix/hosts/demo.nix
        ];
      };

      checks.${system}.demo = self.nixosConfigurations.demo.config.system.build.toplevel;
    };
}
