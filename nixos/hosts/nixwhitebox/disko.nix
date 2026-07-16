{ pkgs, ... }:

{
  imports = [ ../../disks.nix ];

  boot.swraid.enable = true;
  boot.initrd.availableKernelModules = [ "raid1" ];

  boot.loader.systemd-boot.extraInstallCommands = ''
    ${pkgs.rsync}/bin/rsync -a --delete /boot/efi/ /boot2/
  '';

  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
              };
            };
            data = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };
      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot2";
                mountOptions = [ "nofail" ];
              };
            };
            data = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };
    };
    mdadm.data = {
      type = "mdadm";
      level = 1;
      metadata = "1.2";
      content = {
        type = "luks";
        name = "cryptvg";
        passwordFile = "/tmp/disko-password";
        settings.allowDiscards = true;
        extraFormatArgs = [ "--type luks2" "--pbkdf argon2id" ];
        content = {
          type = "lvm_pv";
          vg = "cryptvg";
        };
      };
    };
  };
}
