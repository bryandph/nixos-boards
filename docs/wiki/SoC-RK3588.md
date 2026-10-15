# Rockchip RK3588

`soc-rk3588` is shared by every RK3588 and RK3588S board here: one mainline
kernel definition (`linuxPackages_latest`, provider `mainline`), a lean
initrd (NVMe, MMC, USB HID, LVM/LUKS), the `ondemand` governor and
redistributable firmware. Its `supportedFilesystems` is forced to vfat,
exfat, ext4 and btrfs. A consumer that pins another kernel labels it:

```nix
boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor
  (inputs.nixos-boards.lib.withProvider "mainline" pkgs.linux_6_18));
```

## Boot chain and image

The boot ROM loads `u-boot-rockchip.bin` from sector 64 of the boot medium:
Rockchip's DDR-init TPL (nixpkgs `rkbin`, `unfreeRedistributableFirmware`),
U-Boot SPL, TF-A and U-Boot, all from nixpkgs or built from source. U-Boot
boots NixOS through extlinux on the FAT `BOOT` partition.

`soc-rk3588-image` (**layout version 1**): 32 MiB reserved before `BOOT`
(U-Boot at 32 KiB), `BOOT` (200 MiB unless the board sets more) and an ext4
root labelled `NIXOS_SD`. Boards set the U-Boot package and, where needed, a
fixed root partition UUID and whether the image is compressed.

## Recovery

- **A generation does not boot:** pick the previous one from the extlinux
  menu on the serial console.
- **U-Boot is damaged:** write a known-good image to an SD card and boot
  from it; on the Turing RK1, reflash through the Turing Pi 2 BMC.
- Nothing in this repository writes SPI flash.

## Boards

| Board | SoC | Hardware here | U-Boot |
| --- | --- | --- | --- |
| [Turing RK1](Turing-RK1) | RK3588 | yes | nixpkgs `ubootTuringRK1` |
| [Orange Pi 5](Orange-Pi-5) | RK3588S | yes | nixpkgs `ubootOrangePi5` |
| [Orange Pi 5 Plus](Orange-Pi-5-Plus) | RK3588 | no | nixpkgs `ubootOrangePi5Plus` |
| [ROCK 5A](ROCK-5A) | RK3588S | no | built from `rock5a-rk3588s_defconfig` |

The Orange Pi 5 Pro and 5B are not here yet: the 5 Pro needs a vendor
kernel whose embedded Mali firmware has no established license and has no
upstream device tree, and the 5B has no upstream U-Boot configuration.
