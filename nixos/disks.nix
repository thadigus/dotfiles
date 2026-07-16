{ swapSize, ... }:

{
  disko.devices.lvm_vg.cryptvg = {
    type = "lvm_vg";
    lvs = {
      swap = {
        size = swapSize;
        content = {
          type = "swap";
          resumeDevice = true;
        };
      };
      root = {
        size = "100%FREE";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
}
