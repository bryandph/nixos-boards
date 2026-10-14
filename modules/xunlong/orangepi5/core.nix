# Orange Pi 5 (RK3588S) on the mainline kernel and the upstream device
# tree: GMAC ethernet with the YT8531 PHY, PCIe/NVMe, CPU DVFS and UART.
# The vendor kernel's NPU, VPU and Mali power domains raise an async
# SError on headless boots of this board, so no vendor provider is offered.
{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588;
in {
  flake.modules.nixos.orangepi5-core = {lib, ...}: {
    imports = [soc-rk3588];

    hardware.boards.identity = {
      board = "orangepi5";
      vendor = "xunlong";
      soc = "rk3588s";
      bootChain = "image";
      provider = "mainline";
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/Orange-Pi-5";
    };

    # The pinned upstream board DTS chooses serial2:1500000n8 and enables
    # uart2m0. Put the board UART after sd-image's generic console defaults,
    # without discarding unrelated consumer kernel parameters.
    boot.kernelParams = lib.mkAfter ["earlycon" "console=ttyS2,1500000n8"];

    hardware.deviceTree = {
      enable = true;
      # The mainline arm64 build ships every board's DTB.
      filter = "rk3588s-orangepi-5.dtb";
      name = "rockchip/rk3588s-orangepi-5.dtb";
    };
  };

  flake.nixosModules.orangepi5-core = config.flake.modules.nixos.orangepi5-core;
}
