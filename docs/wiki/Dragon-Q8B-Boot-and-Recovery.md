# Dragon Q8B boot and recovery

See [overview](Dragon-Q8B) and [firmware constraints](Dragon-Q8B-Firmware).

## Board-owned firmware baseline

Observed Radxa OS firmware banner:
`6.0.260818.BOOT.MXF.1.1.c1-00167-MAKENA-1`.
This exact compatibility baseline is recorded in `packages/radxa/dragon-q8b/sources.nix`.
It is **not** a proven minimum version or a verified NixOS BIOS configuration.
The original firmware bytes/hash and redistribution rights are unestablished;
the manifest blocks UEFI packaging/update at licensing level. Existing firmware on
SPI is not downloaded, repackaged or automatically overwritten by this BSP.

## Firmware settings / third-party OS

Before testing record the firmware version and its third-party OS/device-tree
selection, Secure Boot state and storage sector size. Those settings are presently
**pending physical inspection**; do not fabricate a vendor menu name.
These fixture EFI binaries are unsigned, so firmware must allow unsigned third-party EFI.
The ESP contains `EFI/BOOT/BOOTAA64.EFI`, a systemd-boot entry, kernel/initrd and
matching Q8B DTB. Firmware must honor the entry's device-tree handoff; that remains
an explicit hardware acceptance test, including firmware reserved-memory fixups.

## Image layout v1

GPT addresses and FAT BPB use the chosen 512 or 4096-byte logical sectors.
Partition 1 starts at 1 MiB: FAT32 ESP, 512 MiB, label `BOOT_Q8B`.
Partition 2: ext4 root, label `NIXOS_Q8B`. Root grows at first boot.
No raw Qualcomm boot partitions or SPI payload are included.
Changing labels/partition placement requires a layout version bump; v1 has no
in-place migration from vendor OS media. Re-image spare media and preserve the
working vendor microSD for recovery.

Only write an image after manually verifying the target disk and its logical
sector size. Image creation/building is not authorization to erase or flash a device.

## Bootstrap handoff and recovery

The image's one-shot entry is `loader/entries/dragon-q8b-bootstrap.conf`, with
assets in `dragon-q8b-bootstrap/`. The initial profile protects its init closure.
On first boot, `register-nix-paths.service` loads `/nix-path-registration` into the
store database and sets the system profile before the Nix daemon. A separate,
normally ordered `install-initial-bootloader.service` then installs managed NixOS
generation entries. Only after the builder succeeds does its post-install hook
remove the owned bootstrap entry/assets; managed and unknown files are preserved.
The registration marker is removed last. Later switches and generation GC use
the normal NixOS loader entries, not a stale handwritten init path.

If registration fails, the install unit's dependency prevents cleanup. If loader
installation fails, the bootstrap and marker remain for the next boot's retry.
From the local console inspect:

```console
journalctl -b -u register-nix-paths -u install-initial-bootloader
findmnt /boot
ls /boot/loader/entries
```

Repair the cause (for example an unavailable/full ESP), then restart registration
if it failed and run `systemctl restart install-initial-bootloader`. Do not delete
the marker or bootstrap to hide an error. Keep the vendor microSD as recovery;
restore it with power disconnected if the test media does not boot.

Full registration → normal-unit ordering → managed builder → cleanup, including
failure preservation/retry, is an explicit **physical acceptance test**. Build and
cleanup/topology tests do not prove EFI runtime behavior or a real boot/GC cycle.

## Updates and recovery

Use Radxa's current [downloads](https://docs.radxa.com/en/dragon/q8b/download) and
[USB installation/recovery documentation](https://docs.radxa.com/en/dragon/q8b/getting-started/install-system/usb-system)
for a board-owned firmware update/recovery. Read all applicable terms first and
retain a recovery-capable host/cable. No firmware writer is exported while license
and payload provenance remain unknown. Do not apply a Lenovo X13s UEFI payload to Q8B.

For media failures, disconnect power before removing NVMe/UFS, restore a known
working vendor microSD and capture UART0 at 115200 8N1. Never connect adapter VCC.
The vendor's advertised media order is USB > microSD > NVMe > UFS; it does not
prove the earlier Qualcomm ROM/XBL stage falls back when an attached module fails.
