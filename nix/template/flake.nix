{
  inputs.oninix.url = "github:ilyakubryakov/omnissiah-desktop/oninix";
  inputs.nixpkgs.follows = "oninix/nixpkgs";

  outputs = { oninix, nixpkgs, ... }: {
    nixosConfigurations.oninix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        oninix.nixosModules.default
        { system.extraDependencies = [ oninix.outPath ]; }
        oninix.inputs.disko.nixosModules.disko
        ./disko.nix
        ./hardware-configuration.nix
        ./settings.nix
      ];
    };
  };
}
