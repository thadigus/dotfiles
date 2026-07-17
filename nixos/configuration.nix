{ config, pkgs, ... }:

{
  imports = [
    ./bootloader.nix
  ];

  system.stateVersion = "25.05";
  boot.initrd.systemd.enable = true;
  hardware.graphics.enable = true;

  nixpkgs.config.allowUnfree = true; # eventually move away from Nvidia drivers
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
  };

  time.timeZone = "America/Indiana/Indianapolis";

  users.mutableUsers = true;
  users.users.thadigus = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
