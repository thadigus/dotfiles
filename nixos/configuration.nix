{ config, pkgs, ... }:

{
  imports = [
    ./bootloader.nix
    ./home.nix
  ];

  boot.initrd.systemd.enable = true;

  time.timeZone = "America/Indiana/Indianapolis";
  users.mutableUsers = true;
  users.users.thadigus = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
