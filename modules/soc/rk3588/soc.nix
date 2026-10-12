# Rockchip RK3588/RK3588S: mainline kernel, a lean initrd and the
# extlinux boot path shared by every RK3588 board. One kernel definition
# for all of them (platform-providers spec); consumers that pin another
# release label it with lib.withProvider.
{config, ...}: let
  boardsLib = config.boards.lib;
  inherit (config.flake.modules.nixos) hardware-boards;
in {
  flake.modules.nixos.soc-rk3588 = {
    config,
    lib,
    pkgs,
    ...
  }: let
    installDtbs = ''
      ${pkgs.coreutils}/bin/mkdir -p /boot/dtb/base
      ${pkgs.coreutils}/bin/cp -r ${config.hardware.deviceTree.package}/rockchip/* /boot/dtb/base/
      ${pkgs.coreutils}/bin/sync
    '';
  in {
    key = "nixos-boards#soc-rk3588";
    imports = [hardware-boards];

    powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

    boot = {
      kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor (boardsLib.withProvider "mainline" pkgs.linuxPackages_latest.kernel));
      supportedFilesystems = lib.mkForce [
        "vfat"
        "fat32"
        "exfat"
        "ext4"
        "btrfs"
      ];
      # Only the modules needed to reach the root filesystem.
      initrd.includeDefaultModules = lib.mkForce false;
      initrd.availableKernelModules = lib.mkForce [
        "nvme"
        "mmc_block"
        "hid" # USB keyboards for recovery and LUKS prompts
        "dm_mod" # LVM and LUKS
        "dm_crypt" # LUKS
        "input_leds"
      ];
      # Copy the board DTBs to /boot/dtb/base for UEFI boot. Without GRUB or
      # systemd-boot this does nothing.
      loader = {
        systemd-boot.extraInstallCommands = installDtbs;
        grub.extraInstallCommands = installDtbs;
      };
    };

    hardware.enableRedistributableFirmware = lib.mkForce true;
  };

  flake.nixosModules.soc-rk3588 = config.flake.modules.nixos.soc-rk3588;
}
