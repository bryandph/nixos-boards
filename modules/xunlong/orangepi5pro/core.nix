# Orange Pi 5 Pro (RK3588S) on the mainline kernel and the upstream device
# tree: the Motorcomm YT6801 PCIe NIC (in-tree dwmac-motorcomm), NVMe,
# eMMC, CPU DVFS, panthor with linux-firmware's Mali CSF firmware, and
# UART2. The board DTS is first in Linux 7.3.
{config, ...}: let
  boardsLib = config.boards.lib;
  inherit (config.flake.modules.nixos) soc-rk3588;
in {
  flake.modules.nixos.orangepi5pro-core = {
    lib,
    pkgs,
    ...
  }: let
    # Until linuxPackages_latest reaches 7.3, use the release candidate
    # (linuxPackages_testing), unpatched and so still provider `mainline`.
    # Once it does, soc-rk3588's linuxPackages_latest applies and
    # checks.orangepi5pro-kernel fails: delete this override then.
    needsTesting = lib.versionOlder pkgs.linuxPackages_latest.kernel.version "7.3";
  in {
    imports = [soc-rk3588];

    hardware.boards.identity = {
      board = "orangepi5pro";
      vendor = "xunlong";
      soc = "rk3588s";
      bootChain = "image";
      provider = "mainline";
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/Orange-Pi-5-Pro";
    };

    boot.kernelPackages = lib.mkIf needsTesting (pkgs.linuxPackagesFor (boardsLib.withProvider "mainline" pkgs.linuxPackages_testing.kernel));

    warnings = lib.optional needsTesting ''
      orangepi5pro uses Linux ${pkgs.linuxPackages_testing.kernel.version} (linuxPackages_testing), a release candidate, because linuxPackages_latest (${pkgs.linuxPackages_latest.kernel.version}) has no rk3588s-orangepi-5-pro.dtb. See https://github.com/bryandph/nixos-boards/wiki/Orange-Pi-5-Pro.
    '';

    # The upstream board DTS chooses serial2:1500000n8 and enables
    # uart2m0. Put the board UART after sd-image's generic console defaults,
    # without discarding unrelated consumer kernel parameters.
    boot.kernelParams = lib.mkAfter ["earlycon" "console=ttyS2,1500000"];

    hardware.deviceTree = {
      enable = true;
      # The mainline arm64 build ships every board's DTB.
      filter = "rk3588s-orangepi-5-pro.dtb";
      name = "rockchip/rk3588s-orangepi-5-pro.dtb";
    };
  };

  flake.nixosModules.orangepi5pro-core = config.flake.modules.nixos.orangepi5pro-core;
}
