# U-Boot for the Orange Pi 5 Pro. Upstream U-Boot (2026.04) has no board
# configuration, so nixpkgs' U-Boot is built with Armbian's GPL-2.0+
# source patch, which adds orangepi-5-pro-rk3588s_defconfig, the board DTS
# and its binding entry. Pinned at armbian/build 413a42c5 ("orangepi5pro:
# dts: Fix incorrect GRF node name", 2025-07-30), the last revision of the
# v2025.07 patch; Armbian replaced it on main with a v2025.10 series
# (2a85514a). It applies to 2026.04 with offsets.
# u-boot-rockchip.bin combines TPL (nixpkgs rkbin), SPL, TF-A and U-Boot.
{
  buildUBoot,
  armTrustedFirmwareRK3588,
  fetchurl,
  rkbin,
}:
buildUBoot {
  defconfig = "orangepi-5-pro-rk3588s_defconfig";
  extraMeta.platforms = ["aarch64-linux"];
  extraPatches = [
    (fetchurl {
      name = "armbian-0001-add-orangepi5-pro-support.patch";
      url = "https://raw.githubusercontent.com/armbian/build/413a42c5e68d0f3b4220f28cacd36ac33339d7ec/patch/u-boot/v2025.07/board_orangepi5pro/0001-add-orangepi5-pro-support.patch";
      hash = "sha256-cU7V/IloWE/WAl4+V5TRc7rwGriU3XHzW8NDQcRj7SI=";
    })
  ];
  env = {
    BL31 = "${armTrustedFirmwareRK3588}/bl31.elf";
    ROCKCHIP_TPL = rkbin.TPL_RK3588;
  };
  filesToInstall = [
    "u-boot-rockchip.bin"
    "u-boot-rockchip-spi.bin"
  ];
}
