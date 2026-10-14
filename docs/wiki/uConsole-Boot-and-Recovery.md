# uConsole: boot and recovery

## Boot chain

The CM5's EEPROM bootloader loads the Raspberry Pi firmware from the
image's FAT firmware partition. The firmware reads `config.txt`, applies
the device-tree overlays and starts the kernel (nixos-raspberrypi's
`kernelboot` loader). The firmware partition is written by NixOS on every
switch; the EEPROM is not touched by this repository.

The firmware ignores every `dtoverlay=` line unless the overlay directory
contains a `README` file, so the board kernel adds one. Without it the CM5
would also miss `bcm2712d0.dtbo`, which corrects pinctrl addresses on D0
silicon.

## Image layout

**Version 1:** nixos-raspberrypi's firmware partition plus an ext4 root
labelled `NIXOS_SD`. Installations on NVMe (for example with disko) define
their own `fileSystems."/"`.

## Recovery

- **Does not boot after a switch:** select the previous generation. If the
  firmware partition is damaged, write a fresh image to an SD card and
  boot from it; the CM5 Lite boots from SD.
- **Battery drained until it wedged:** with the PMIC rails stuck on and the
  charger cycling, only removing the batteries recovers it.
  `uconsole-core` powers off at 8% to avoid this.
- **EEPROM bootloader:** use Raspberry Pi's `rpi-eeprom` tools or
  rpiboot; this repository never writes the EEPROM.
