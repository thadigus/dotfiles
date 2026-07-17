{
  description = "Thad's Endpoint NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, lanzaboote, home-manager, ... }:
    let
      mkHost = hostName: swapSize: extraModules:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit hostName swapSize; };
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            ./nixos/configuration.nix
            {
              networking.hostName = hostName;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.thadigus = import ./nixos/home.nix;
            }
          ] ++ extraModules;
        };
    in {
      nixosConfigurations = {
        nixlaptop = mkHost "nixlaptop" "32G" [ ./nixos/hosts/nixlaptop lanzaboote.nixosModules.lanzaboote ];
        nixwhitebox = mkHost "nixwhitebox" "32G" [ ./nixos/hosts/nixwhitebox ];
      };
    };
}
