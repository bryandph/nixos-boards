# SD-card image layout for the BeagleY-AI. Free: the boot firmware partition
# receives tiboot3.bin, tispl.bin and u-boot.img only when
# beagley-ai-boot-bundle (non-free) is composed as well.
{config, ...}: {
  flake.modules.nixos.beagley-ai-image = {
    config,
    lib,
    pkgs,
    modulesPath,
    ...
  }: {
    imports = [(modulesPath + "/installer/sd-card/sd-image.nix")];
    # Layout 1: FAT BEAGLEYBOOT (active, type 0x0e, 512 MiB at 8 MiB) and
    # ext4 BEAGLEY_ROOT.
    hardware.boards.image.layoutVersion = 1;
    hardware.enableAllHardware = lib.mkForce false;
    # The legacy initrd already includes util-linux blkid and BusyBox readlink.
    # This image profile owns SD root only; reusable core imposes no such rule.
    boot.initrd.postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) (lib.mkAfter ''
      waitDevice /dev/disk/by-label/BEAGLEY_ROOT || true
      waitDevice /dev/disk/by-label/BEAGLEYBOOT || true
      udevadm settle
      ${builtins.readFile ../../../packages/beagleboard/beagley-ai/sd-identity-guard.sh}
      while ! beagley_check_sd_identity; do
        echo "Refusing ambiguous or non-SD BeagleY-AI root/boot filesystems."
        fail
      done
    '');
    boot.initrd.systemd.services.beagley-sd-identity = lib.mkIf config.boot.initrd.systemd.enable {
      description = "Validate unique BeagleY-AI SD root and boot identities";
      requiredBy = ["sysroot.mount"];
      before = ["sysroot.mount"];
      requires = [
        "dev-disk-by\\x2dlabel-BEAGLEY_ROOT.device"
        "dev-disk-by\\x2dlabel-BEAGLEYBOOT.device"
      ];
      after = [
        "dev-disk-by\\x2dlabel-BEAGLEY_ROOT.device"
        "dev-disk-by\\x2dlabel-BEAGLEYBOOT.device"
        "systemd-udev-settle.service"
      ];
      wants = ["systemd-udev-settle.service"];
      unitConfig = {
        DefaultDependencies = false;
        OnFailure = "emergency.target";
      };
      serviceConfig.Type = "oneshot";
      path = [pkgs.util-linux pkgs.coreutils];
      script = ''
        ${builtins.readFile ../../../packages/beagleboard/beagley-ai/sd-identity-guard.sh}
        beagley_check_sd_identity
      '';
    };
    # Initial recovery image intentionally owns only the SD. NVMe stays unmounted.
    fileSystems = lib.mkForce {
      "/" = {
        device = "/dev/disk/by-label/BEAGLEY_ROOT";
        fsType = "ext4";
      };
      "/boot" = {
        device = "/dev/disk/by-label/BEAGLEYBOOT";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };
    sdImage = {
      firmwareSize = 512;
      firmwarePartitionOffset = 8;
      firmwarePartitionID = "0x42474149";
      firmwarePartitionName = "BEAGLEYBOOT";
      rootVolumeLabel = "BEAGLEY_ROOT";
      populateRootCommands = "";
      populateFirmwareCommands = ''
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d firmware
      '';
    };
    # K3 ROM needs the FAT partition active with partition type 0x0e.
    # Fail if the upstream image builder changes these construction points.
    system.build.beagleyAiSdImage = config.system.build.sdImage.overrideAttrs (old: let
      before = ["type=b\n" "type=83, bootable" "mkfs.vfat --invariant"];
      # Match k3_common.inc's no-alignment formatting so FAT fills the partition.
      after = ["type=e, bootable\n" "type=83" "mkfs.vfat -a -F 16 --invariant"];
    in {
      buildCommand = assert lib.all (s: lib.hasInfix s old.buildCommand) before;
        lib.replaceStrings before after old.buildCommand;
    });
  };

  flake.nixosModules.beagley-ai-image = config.flake.modules.nixos.beagley-ai-image;
}
