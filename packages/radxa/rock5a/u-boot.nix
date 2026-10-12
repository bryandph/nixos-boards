# Mainline U-Boot for the ROCK 5A; rock5a-rk3588s_defconfig is upstream.
# u-boot-rockchip.bin combines TPL (nixpkgs rkbin), SPL, TF-A and U-Boot.
{
  buildUBoot,
  armTrustedFirmwareRK3588,
  rkbin,
}:
buildUBoot {
  defconfig = "rock5a-rk3588s_defconfig";
  extraMeta.platforms = ["aarch64-linux"];
  BL31 = "${armTrustedFirmwareRK3588}/bl31.elf";
  ROCKCHIP_TPL = rkbin.TPL_RK3588;
  filesToInstall = [
    "u-boot-rockchip.bin"
    "u-boot-rockchip-spi.bin"
  ];
}
