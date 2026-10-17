# Orange Pi 5 Pro

The Orange Pi 5 Pro (RK3588S) runs the mainline kernel and the upstream `rk3588s-orangepi-5-pro.dtb`: the Motorcomm YT6801 PCIe Ethernet controller (in-tree `dwmac-motorcomm`), NVMe on PCIe2, eMMC, CPU DVFS, the Mali GPU through panthor and linux-firmware's `arm/mali/arch10.8` firmware, the PWM LEDs and the debug UART. Maintainers have this board; no function has been verified on it yet.

The board DTS is first in Linux 7.3. Until nixpkgs' `linuxPackages_latest` reaches 7.3, `orangepi5pro-core` uses `linuxPackages_testing` (7.3-rc), unpatched and labelled provider `mainline`, and prints a warning. When latest reaches 7.3 the core falls back to `soc-rk3588`'s kernel and `checks.orangepi5pro-kernel` fails, so the override is removed at the next nixpkgs update.

| Feature | Provides |
| --- | --- |
| `orangepi5pro-core` | Mainline kernel (7.3-rc until 7.3 is in nixpkgs), the upstream device tree and console (`ttyS2`, 1500000 baud) |
| `orangepi5pro-image` | SD/eMMC image (`soc-rk3588-image`, layout version 1) |
| `orangepi5pro-ethernet-10-100` | Advertises only 10/100 Mbps on the YT6801, which does not train 1000BASE-T on this board; adds `ethtool` |
| `orangepi5pro-leds-off` | Turns off the `blue:status` and `green:activity` LEDs through udev |

```nix
imports = with inputs.nixos-boards.nixosModules; [
  orangepi5pro-core
  orangepi5pro-image
  orangepi5pro-ethernet-10-100 # optional
  orangepi5pro-leds-off # optional
];
```

Build `config.system.build.sdImage`. The board needs no release manifest:
U-Boot's TPL and TF-A come from nixpkgs and runtime firmware from
linux-firmware and nixpkgs' `raspberrypi-wireless-firmware`. Status of each function: [hardware matrix](Orange-Pi-5-Pro-Hardware-Matrix).
Boot chain, layout and recovery: [boot and recovery](Orange-Pi-5-Pro-Boot-and-Recovery)
and [Rockchip RK3588](SoC-RK3588).

## Ethernet

The YT6801 binds to the `dwmac-motorcomm` PCI driver, and stmmac reports
the driver as `st_gmac` through ethtool. systemd `.link` and `.network`
`Driver=` matches use that ethtool name, `ID_NET_DRIVER=st_gmac`. The board
DTS enables no on-SoC GMAC, so `st_gmac` names only the YT6801. The
out-of-tree `yt6801` package is not used.

## Wi-Fi and Bluetooth

The AP6256 module (`brcm,bcm43456-fmac` on SDIO, `brcm,bcm4345c5` on UART9)
is described by the device tree. linux-firmware has no BCM43456 or
BCM4345C5 files. nixpkgs' `raspberrypi-wireless-firmware` (RPi-Distro
firmware-nonfree and bluez-firmware, `unfreeRedistributableFirmware`),
which `soc-rk3588`'s redistributable firmware already installs, provides
`brcm/brcmfmac43456-sdio.{bin,clm_blob,txt}` and `brcm/BCM4345C5.hcd`, so
the kernel finds firmware under the generic names. That NVRAM file is the
Raspberry Pi 400 and CM4 calibration, not the AP6256's; the board-specific
NVRAM in orangepi-xunlong/firmware has no license and is not used. Both
functions are `implemented-unverified`.
