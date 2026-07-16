{
  description = "Thad's Endpoint NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, lanzaboote, ... }:
    let
      mkHost = hostName: swapSize: extraModules:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit hostName swapSize; };
          modules = [
            disko.nixosModules.disko
            ./configuration.nix
            { networking.hostName = hostName; }
          ] ++ extraModules;
        };
    in {
      nixosConfigurations = {
        nixlaptop = mkHost "nixlaptop" "32G" [ ./hosts/nixlaptop lanzaboote.nixosModules.lanzaboote ];
        nixwhitebox = mkHost "nixwhitebox" "32G" [ ./hosts/nixwhitebox ];
      };
    };
}
