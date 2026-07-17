{ lib, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  boot.initrd.luks.devices.cryptvg.crypttabExtraOpts = [ "fido2-device=auto" ];

  environment.systemPackages = [ pkgs.sbctl ];
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.nvidia.offload.enableOffloadCmd = true;
}
