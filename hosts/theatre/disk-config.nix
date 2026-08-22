{
  disko.devices.disk.main = {
    type = "disk";
    # This identifies only the internal Samsung NVMe, not a transient /dev/sdX.
    device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_1TB_S7HDNS0YB07160D";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["fmask=0077" "dmask=0077"];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f" "-L" "nixos"];
            subvolumes = {
              "/root" = {
                mountpoint = "/";
                mountOptions = ["compress=zstd" "noatime"];
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = ["compress=zstd" "noatime"];
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = ["compress=zstd" "noatime"];
              };
            };
          };
        };
      };
    };
  };
}
