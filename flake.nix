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

      nixosConfigurations.iso = lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit disko;
          oninixSource = self.outPath;
        };
        modules = [
          self.nixosModules.default
          ./nix/hosts/iso.nix
        ];
      };

      packages.${system}.iso = self.nixosConfigurations.iso.config.system.build.isoImage;
      checks.${system} = {
        demo = self.nixosConfigurations.demo.config.system.build.toplevel;
        tests = nixpkgs.legacyPackages.${system}.callPackage ./nix/checks.nix { };
      };
    };
}
