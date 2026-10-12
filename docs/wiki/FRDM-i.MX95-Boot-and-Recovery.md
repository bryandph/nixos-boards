# FRDM-i.MX95: boot and recovery

## Boot chain

The i.MX 95 boot ROM authenticates and loads the NXP boot container from the
boot medium: OEI trains LPDDR4X with NXP's training firmware, the ELE
firmware and System Manager run on the M33, and U-Boot (with TF-A and
OP-TEE) boots NixOS through extlinux. `frdm-imx95-boot-container` assembles
the container from source plus NXP's ELE and LPDDR4X files with
imx-mkimage's `flash_a55` target, which keeps the M33 System Manager and
omits NXP's prebuilt M7 demonstration. The complete NXP container
(`legacyPackages.aarch64-linux.frdm-imx95.complete-boot-container`) remains
available for compatibility and recovery.

The container's bytes depend on the toolchain. Its size and SHA-256 are
pinned, and a different result fails the build; record a new identity only
after accepting it on hardware.

## Image layout

**Version 1.**

The image reserves the first 8 MiB, installs the NXP boot container at the
vendor-defined 32 KiB offset, and installs a generated U-Boot environment at
NXP's 7 MiB offset. The environment supplies non-overlapping kernel, DTB, and
initrd load addresses and makes bootflow consume the generation-aware extlinux
entry at the FAT root. The 512 MiB FAT `BOOT` partition is marked active for
NXP U-Boot. A systemd generator derives `/boot` partition 1 from the physical
MMC device hosting `/`, so duplicate labels and UUIDs on simultaneously
attached SD and eMMC media cannot redirect later NixOS generations to the
wrong extlinux filesystem. The ext4 root uses the stable `NIXOS_SD` identity
and expands on first boot by resolving its kernel major/minor identity through
sysfs rather than assuming a device-node minor number.

No flashing app is provided. These outputs are generic board and evaluation
artifacts: they do not carry fleet identity, operator SSH keys, or secrets.
Feature acceptance uses removable media only and leaves the installed/eMMC
fleet system untouched for rollback. The complete-container provider remains
available if source assembly needs to be ruled out during diagnosis.

## Installing to eMMC

This destructive procedure is for deliberate generic board provisioning, not
feature-image acceptance or fleet rollout. Fleet identity, SSH authorization,
and secrets belong to the consuming fleet configuration and are not provided
by this repository. Feature evaluations must not use this procedure.

Treat eMMC installation as two separate writes: the generated image goes to
the eMMC user area, while NXP's signed boot container goes to eMMC boot
partition 1 through the ROM's USB serial downloader. The latter step removes
any dependency on a factory-installed boot container that happened to remain
in the hardware boot partition.

First boot and accept the generic image from an independently identified SD
card. Establish verified offline backups and a reviewed out-of-band recovery
path before changing eMMC. From the running SD system:

1. Use `findmnt /`, `findmnt /boot`, `lsblk`, and
   `/sys/block/mmcblk*/device/type` to distinguish the mounted SD device from
   the inactive eMMC. Do not infer the target from a previously observed
   `mmcblk` number.
2. Save the eMMC user area, both hardware boot partitions
   (`mmcblkXboot0` and `mmcblkXboot1`), the partition table, sizes, and hashes
   to separate recovery storage. A backup of `mmcblkX` alone does **not**
   include the hardware boot partitions.
3. Prove the recovery environment and saved-artifact inventory before writing
   eMMC.
4. Decompress the accepted image into the independently verified, unmounted
   eMMC user-area device. Flush it, then hash exactly the image-length prefix
   read back from that device and compare it with the decompressed image.

For example, after replacing both placeholders with paths established during
the preflight:

```console
image=/path/to/nixos-frdm-imx95.img.zst
target=/dev/mmcblkX  # replace X only after completing the preflight

image_bytes="$(zstd -dc "$image" | wc -c)"
image_sha256="$(zstd -dc "$image" | sha256sum | cut -d' ' -f1)"
zstd -dc "$image" | sudo dd of="$target" bs=4M conv=fsync status=progress
sudo blockdev --flushbufs "$target"
sudo head -c "$image_bytes" "$target" | sha256sum
```

The final hash must equal `$image_sha256`. Power off after verification.
Because SD and eMMC copies use the same `BOOT` and `NIXOS_SD` identities,
remove the SD card before accepting the eMMC boot.

### Programming the eMMC hardware boot partition

Use a Linux host for the tested UUU path. On macOS 26, UUU may fail to claim
the ROM device because of the open
[libusb/HID regression](https://github.com/nxp-imx/mfgtools/issues/510).

1. Build the current licensed container and resolve its output dynamically:

   ```console
   boot_output="$(
     nix build --no-link --print-out-paths \
       github:bryandph/nixos-boards#legacyPackages.aarch64-linux.frdm-imx95.source-boot-container
   )"
   boot_container="$boot_output/imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55"
   ```

2. With power off, connect the board's USB1/J3 port to the Linux host and
   select serial-download boot as described by NXP's board guide. After a
   complete power cycle, UUU must identify the device as `MX95` using the
   `SDPS` protocol:

   ```console
   uuu_output="$(
     nix build --no-link --print-out-paths nixpkgs#uuu
   )"
   sudo "$uuu_output/bin/uuu" -lsusb
   ```

3. Program only the bootloader:

   ```console
   sudo "$uuu_output/bin/uuu" -b emmc "$boot_container"
   ```

The tested `-b emmc` flow writes boot partition 1 and selects it in eMMC
`PARTITION_CONFIG`; it does not rewrite the user area installed above. UUU
also provides an `emmc_all` workflow, but this repository has not validated
that path with the generated compressed NixOS image.

Return the switches to eMMC boot, disconnect the serial-download cable if
necessary, and power-cycle. Accept the result only after:

- the boot-container-length prefix of `mmcblkXboot0` hashes identically to the
  locally built container;
- `mmc extcsd read` reports boot partition 1 enabled;
- `/` and `/boot` resolve to the eMMC partitions and the root filesystem has
  expanded;
- all six A55 CPUs, MAC-based DHCP, and the expected NixOS generation are
  present;
- `systemctl --failed` is empty; and
- a second eMMC boot passes the same checks.

For feature validation, rollback is instead powering off, removing the
evaluation SD, and booting the untouched known-good installed/eMMC fleet
system. Recovery from this optional destructive provisioning workflow uses the
verified offline user-area and boot-partition backups.

Factory restoration is a separate, reviewed operation. Boot an independently
verified recovery environment, repeat the device-identity preflight, and
verify every saved artifact before writing anything. Restore the user-area
image only to the inactive eMMC user area. Restore `boot0` and `boot1` to their
matching hardware partitions, temporarily clearing each partition's
`force_ro` sysfs control only for its write and restoring it immediately
afterward. Reapply the saved eMMC boot configuration if it differs, then
perform length-limited readback hashes of all three areas before selecting
eMMC boot. Neither the backups nor licensed NXP artifacts may be published.
