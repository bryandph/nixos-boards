# uConsole

The [ClockworkPi uConsole](https://www.clockworkpi.com/uconsole) is a
handheld with a 5-inch portrait DSI panel, keyboard, speakers and an
AXP228 battery PMIC. This repository supports it with a Raspberry Pi
**CM5** (Lite) compute module.

| | |
| --- | --- |
| Vendor | ClockworkPi |
| SoC | Broadcom BCM2712 (`soc-bcm2712`) |
| Boot chain | `vendor-partition`: Raspberry Pi firmware on the image's firmware partition |
| Provider | `rpi-<release>`: nixos-raspberrypi's `linux_rpi5` with ClockworkPi patches |
| Profiles | free only; no non-free artifacts are needed |

## Features

| Feature | Provides |
| --- | --- |
| `uconsole-core` | Kernel with the ClockworkPi patch series (panel-cwu50 DSI panel, ocp8178 backlight, AXP228 battery and charger, uConsole device-tree overlays); config.txt; speaker/headphone switching; low-battery poweroff |
| `uconsole-image` | SD-card image from nixos-raspberrypi (layout version 1) |
| `uconsole-expansion-aio-v1` | HackerGadgets AIO v1 board: GPS with PPS, RTL-SDR, SX1262 LoRa, PCF85063A RTC |
| `uconsole-expansion-nvme` | HackerGadgets NVMe adapter: PCIe x1 for the M.2 slot |

The AIO GPS daemon listens locally by default; consumers explicitly opt into
remote access. GPS/PPS device nodes use `dialout` group access, not world-write
permissions. The core also claims the overlay's I2C/PMIC, reset and backlight
GPIOs (2/3/8/9 in addition to 10–13).

The two expansion features claim the GPIOs, buses and PCIe lane they use,
so an add-on that needs the same resources fails evaluation. Status of
each function: [hardware matrix](uConsole-Hardware-Matrix).

## Using it

```nix
{
  inputs.nixos-boards.url = "github:bryandph/nixos-boards";
  outputs = {nixpkgs, nixos-boards, ...}: {
    nixosConfigurations.uconsole = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = with nixos-boards.nixosModules; [
        uconsole-core
        uconsole-image
        uconsole-expansion-aio-v1 # if fitted
        uconsole-expansion-nvme # if fitted
        ./configuration.nix
      ];
    };
  };
}
```

`uconsole-core` sets `console=tty1`, `fbcon=rotate:1` and `quiet` with
`lib.mkForce`, because the uConsole has no serial header and
`console=ttyAMA0` would corrupt the AIO board's GPS data. Add kernel
parameters with `lib.mkForce` as well; same-priority lists are merged.

Build the image:

```console
nix build .#nixosConfigurations.uconsole.config.system.build.sdImage
```

## Firmware

The uConsole uses no artifacts from release manifests. Its firmware comes
from upstream and is licensed `unfreeRedistributableFirmware`, which
nixpkgs counts as free:

- Raspberry Pi boot firmware (`raspberrypifw`), from
  [raspberrypi/firmware](https://github.com/raspberrypi/firmware) through
  nixos-raspberrypi;
- CM5 Wi-Fi and Bluetooth firmware (`raspberrypiWirelessFirmware`) and
  `linux-firmware`, from nixpkgs.

## Provenance of the patches

The kernel patches are extracted from
[ak-rex/ClockworkPi-linux](https://github.com/ak-rex/ClockworkPi-linux)
(branch `rpi-7.1.y`) and rebased onto `rpi-6.18.y`. They are GPL-2.0 like
the kernel. See `packages/clockworkpi/uconsole/kernel.nix`.

The locked kernel is `6.18.64-unstable_20261118` (Raspberry Pi source
`71edfd62996a0d816039c9c1092222f3795fa2fc`). The rebase is build-verified
only: the hardware was unreachable, so no hardware acceptance is claimed.

- `0001`: only the adjacent EBBG Kconfig context changed after
  [the GPIOLIB dependency fix](https://github.com/raspberrypi/linux/commit/b2a75ce2af881d33a43524de187a416bc4eee3fc)
  (mainline `ae3aa8cf5fd5ccb428a814e7eb38ae33ad1cfa34`); the CWU50 driver
  and its configuration are unchanged.
- `0002` (OCP8178 backlight) and `0003` (overlays) apply unchanged.
- `0004`: the battery driver, including AXP228 fuel-gauge calibration and
  V_OFF plumbing, and the AC-event VBUS path kick are unchanged. Only the
  MFD power-off hunk was removed because
  [the upstream CHGLED fix](https://github.com/raspberrypi/linux/commit/1a23e121c92e45dac842febaac7834be6b76cb58)
  (mainline `3756bf05c963563f1325af105356541882dd5899`) already preserves
  the register's other bits with `regmap_set_bits()`. Around line 1250 of
  `drivers/mfd/axp20x.c`, that replaced the old full-register
  `regmap_write()` matched by our hunk, causing the patch failure. Upstream
  preserves CHGLED on AXP221/AXP223/AXP228, as our hunk did, and also preserves
  unrelated control bits on the other PMIC variants; no local power feature
  was dropped.

## See also

- [Boot and recovery](uConsole-Boot-and-Recovery)
- [Firmware](uConsole-Firmware) and [free vs non-free](uConsole-Free-vs-NonFree)
