# SD/eMMC image for RK3588 boards: U-Boot (TPL, SPL, TF-A and U-Boot in
# u-boot-rockchip.bin) at sector 64, the Rockchip boot-ROM offset, a FAT
# BOOT partition from 32 MiB holding extlinux, and an ext4 root. Boards set
# the U-Boot package and their layout values.
{config, ...}: {
  flake.modules.nixos.soc-rk3588-image = {
    config,
    lib,
    modulesPath,
    ...
  }: let
    cfg = config.hardware.boards.rk3588.image;
  in {
    key = "nixos-boards#soc-rk3588-image";
    imports = ["${modulesPath}/installer/sd-card/sd-image-aarch64.nix"];

    options.hardware.boards.rk3588.image = {
      uboot = lib.mkOption {
        type = lib.types.package;
        description = "U-Boot build whose `u-boot-rockchip.bin` is written at sector 64.";
      };
      firmwareSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 200;
        description = "Size of the FAT BOOT partition in MiB.";
      };
      compress = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the image is zstd-compressed (a BMC that flashes raw images needs false).";
      };
      rootPartitionUUID = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Fixed root partition UUID, also passed as `root=UUID=` for boot loaders that need it.";
      };
    };

    config = {
      hardware.boards.image.layoutVersion = lib.mkDefault 1;

      boot = {
        kernelParams = lib.optionals (cfg.rootPartitionUUID != null) [
          "root=UUID=${cfg.rootPartitionUUID}"
          "rootfstype=ext4"
        ];
        loader = {
          grub.enable = lib.mkForce false;
          generic-extlinux-compatible.enable = lib.mkForce true;
        };
      };

      sdImage =
        {
          compressImage = cfg.compress;
          firmwarePartitionOffset = 32;
          firmwarePartitionName = "BOOT";
          inherit (cfg) firmwareSize;
          populateFirmwareCommands = ''
            ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
          '';
          populateRootCommands = ''
            mkdir -p ./files/boot
            mkdir -p ./files/boot/firmware
          '';
          postBuildCommands = ''
            dd if=${cfg.uboot}/u-boot-rockchip.bin of=$img seek=64 conv=notrunc
          '';
        }
        // lib.optionalAttrs (cfg.rootPartitionUUID != null) {
          inherit (cfg) rootPartitionUUID;
        };
    };
  };

  flake.nixosModules.soc-rk3588-image = config.flake.modules.nixos.soc-rk3588-image;
}
