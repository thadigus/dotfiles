{
  imports = [ ../../disks.nix ];

  disko.devices.disk.main = {
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
        cryptvg = {
          size = "100%";
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
    };
  };
}
