# Orange Pi 5 Pro: boot and recovery

Upstream U-Boot has no Orange Pi 5 Pro configuration. nixpkgs' U-Boot
(2026.04) is built with Armbian's GPL-2.0+ source patch, which adds
`orangepi-5-pro-rk3588s_defconfig` and the board DTS, pinned at
armbian/build commit `413a42c5` (`patch/u-boot/v2025.07/board_orangepi5pro/0001-add-orangepi5-pro-support.patch`).
The package is `legacyPackages.aarch64-linux.orangepi5pro.u-boot`. The BOOT
partition is 512 MiB to hold several generations.

The boot chain, image layout (version 1) and recovery are shared by the
RK3588 boards; see [Rockchip RK3588](SoC-RK3588). The boot ROM tries SPI
flash before eMMC and SD, so a boot loader already in SPI flash starts
instead of the image's U-Boot. Nothing in this repository writes SPI flash.
