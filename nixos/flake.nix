{
  description = "Thad's NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      mkHost = hostName: extraModules:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit hostName; };          
	  modules = [
            disko.nixosModules.disko
            ./configuration.nix
            { networking.hostName = hostName; }
          ] ++ extraModules;
        };
    in {
      nixosConfigurations = {
        nixlaptop   = mkHost "nixlaptop"   [ ./hosts/nixlaptop ];
        nixwhitebox = mkHost "nixwhitebox" [ ./hosts/whitebox ];
      };
    };
}
