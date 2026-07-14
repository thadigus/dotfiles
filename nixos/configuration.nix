# Primary Configuration File for Nix System

{ config, pkgs, ... }:

{
  imports = [
    ./disks.nix
    ./bootloader.nix
    ./home.nix
  ];

  time.timeZone = "America/Indiana/Indianapolis";
  users.mutableUsers = true;
  users.users.thadigus = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialHashedPassword = "$y$j9T$M7fw/uS5lVr0ZIXTT9gZr.$l/t3eFrNrgCLIk.1DGtO83qppZsTx1cT10.txBNRiC8";
  };
}
