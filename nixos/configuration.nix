{ config, pkgs, ... }:

{
  imports = [
    ./bootloader.nix
    ./home.nix
  ];

  system.stateVersion = "25.05";
  boot.initrd.systemd.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "America/Indiana/Indianapolis";
  users.mutableUsers = true;
  users.users.thadigus = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
