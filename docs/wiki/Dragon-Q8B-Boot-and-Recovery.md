# Dragon Q8B boot and recovery

See [overview](Dragon-Q8B) and [firmware constraints](Dragon-Q8B-Firmware).

## Board-owned firmware baseline

Observed Radxa OS firmware banner:
`6.0.260818.BOOT.MXF.1.1.c1-00167-MAKENA-1`.
This exact compatibility baseline is recorded in `packages/radxa/dragon-q8b/sources.nix`.
It is the observed baseline for the bounded headless acceptance below, **not** a
proven minimum version or a complete, portable BIOS-settings recipe.
The original firmware bytes/hash and redistribution rights are unestablished;
the manifest blocks UEFI packaging/update at licensing level. Existing firmware on
SPI is not downloaded, repackaged or automatically overwritten by this BSP.

## Firmware settings / third-party OS

Before testing record the firmware version and its third-party OS/device-tree
selection, Secure Boot state and storage sector size. The acceptance below observed
unsigned EFI execution and native Q8B DT boot on the existing firmware configuration;
exact menu names and a general third-party-OS settings recipe were not established.
Do not infer a Secure Boot policy or fabricate a vendor menu name from boot success.
These fixture EFI binaries are unsigned, so firmware must allow unsigned third-party EFI.
The ESP contains `EFI/BOOT/BOOTAA64.EFI`, a systemd-boot entry, kernel/initrd and
matching Q8B DTB. Native DT boot was observed on this baseline; this does not prove
all firmware reserved-memory fixups or compatibility with other firmware releases.

## Image layout v1

GPT addresses and FAT BPB use the chosen 512 or 4096-byte logical sectors.
Partition 1 starts at 1 MiB: FAT32 ESP, 512 MiB, label `BOOT_Q8B`.
Partition 2: ext4 root, label `NIXOS_Q8B`. On first boot, upstream
`boot.growPartition` expands the partition and `fileSystems."/".autoResize`
expands the filesystem to fill it. These are separate operations: check both
partition capacity (`lsblk`) and filesystem capacity/free space (`df`). The
per-field filesystem defaults preserve growth when a consumer overrides the
root device; an explicit `autoResize = false` opts out.

Older images without the filesystem-growth default can have a large partition
but retain the approximately 3 GiB image filesystem. If capacity is insufficient,
use recovery media and verify the exact target device, UUID and unmounted state
before filesystem assessment and ordinary `resize2fs` into the existing
partition. Stop for a repair decision if assessment is not clean; do not format,
change GPT, force resizing, or automatically approve filesystem repairs.
No raw Qualcomm boot partitions or SPI payload are included.
Changing labels/partition placement requires a layout version bump; v1 has no
in-place migration from vendor OS media. Re-image spare media and preserve the
working vendor microSD for recovery.

Only write an image after manually verifying the target disk and its logical
sector size. Image creation/building is not authorization to erase or flash a device.

## Early TPM device availability

The initrd includes the existing vendor `tpm_qcom_qsee` module so udev can
handle the TPM auxiliary device created by built-in QSEECOM before switching
root. TPM2 support stays enabled; no new firmware or kernel configuration is
introduced. Without that module, an initrd TPM device wait can delay boot by
90 seconds even though the device appears later in stage 2. Confirm early-device
timing on hardware; archive/module checks are not TPM attestation evidence.

## Headless hardware acceptance

Historical operator observations on 2026-10-13 used a full-profile consumer,
the Radxa 7.0.11 kernel and its matching native Q8B DT. The publicly reachable
immutable [acceptance receipt and source](https://github.com/bryandph/nixos-boards/commit/622e47f75dc9a3888cbd6b8f8c12231b17a3c2e2)
records these bounded observations; its runtime-source parent is
[`2a25462`](https://github.com/bryandph/nixos-boards/commit/2a254620c8cab3eec4d75c4ef0cdf1c266d66f06).
The receipt changed documentation/status bookkeeping, not the kernel/system/
512/4096 image derivation identities at that source baseline. It is not a claim
that the public fixture was the operator consumer or that later stack relocks
were physically retested. Current consumers require separate exact derivation
identity proof before carrying this historical evidence forward. Such proof
was revalidated for the retained accepted full/headless consumer's kernel,
initrd and complete system; it is not equality to this repository's public
free/full fixtures. Matrix `verified` rows refer to that dated recorded
configuration and its limits, not a new public-fixture hardware test:

- Full-profile 512-byte-sector NVMe boot, UART output and one PCIe Ethernet link
  with DHCP/default route worked. Persistent NVMe selection survived ordinary
  managed warm reboots; the runtime kernel and native board compatibility matched.
- The reviewed initrd exposed `/dev/tpm0` at about 2.66 seconds and `/dev/tpmrm0`
  at about 2.68 seconds. Initrd startup took about 4.5–4.7 seconds, removing the
  earlier 90-second device wait. Early SRK setup skipped its measured-UKI condition;
  this is device-availability evidence, **not** provisioning or attestation.
- An older image had grown GPT but retained its approximately 3 GiB filesystem.
  Guarded offline assessment and ordinary filesystem growth expanded it. On the
  updated managed boot, growpart reported no change before root growfs succeeded
  at about 476.4 GiB. This verifies the renewed hooks/order on an already-expanded
  filesystem, not a fresh image's first-boot expansion from 3 GiB.
- Normal operator SSH/public-key authentication, administrative access, filesystem
  capacity and zero failed stage-2 units were checked. Consumer-provided access
  does not change the public fixtures' local-console-only policy.
- Older managed generations and their GC roots remained available. Reversing the
  persistent NVMe selection reached the preserved vendor microSD; restoring it
  returned to the reviewed NVMe generation. Only proven owned temporary staging
  and transport material was removed. No firmware payload was flashed.

The 512/4096-sector free/full images passed structural checks; 4096-sector
hardware boot was later recorded on UFS (see [UFS boot](#ufs-boot)). The free fixture was built, **not boot-verified**.
The matrix's `free` column describes module/profile availability, not which fixture
was used for these observations. GPU, ADSP, audio and NixOS microSD operation
remain unverified or blocked as separately recorded. This is not a cold-start,
power-failure, all-Ethernet-ports, independently rebuilt kernel or uConsole result.

## UFS boot

Recorded 2026-10-21 on a YMTC `YMUS8A1TE2D1C1` 128 GB UFS module (4096-byte
logical sectors) with UEFI `6.0.260818.BOOT.MXF.1.1.c1-00167` and UFS first in
the firmware's Boot Device Order:

- Radxa rsdk-r7 `resolute_gnome` `output_4096` reached a login prompt, so the
  firmware boots this module.
- The 4096-sector image (full profile, then a full-profile headless consumer)
  booted to userspace with `/` and `/boot` on the UFS, grew the root partition
  and filesystem, and reached zero failed stage-2 units.
- Stage 1 needs the UFS PHY driver (`phy_qcom_qmp_ufs`): `ufs_qcom` finds it by
  device-tree phandle, not module dependency. Without it the root device never
  appears.

Every layout-v1 image shares its labels and GPT identifiers. With images on two
attached disks, `/` and `/boot` can resolve to different disks; keep one image-
written disk attached, or wipe or relabel the others. A reinstall generates new
SSH host keys; restore the host's sealed key if its secrets are encrypted to it.
This is not a cold-start, power-failure or free-fixture result.

## Bootstrap handoff and recovery

The image's one-shot entry is `loader/entries/dragon-q8b-bootstrap.conf`, with
assets in `dragon-q8b-bootstrap/`. The initial profile protects its init closure.
On first boot, `register-nix-paths.service` loads `/nix-path-registration` into the
store database and initializes the system profile before the Nix daemon. Retries
preserve an existing managed generation selection rather than resetting it to an
older generation chosen from the boot menu. A separate,
normally ordered `install-initial-bootloader.service` then installs managed NixOS
generation entries. Only after the builder succeeds does its post-install hook
remove the owned bootstrap entry/assets; managed and unknown files are preserved.
The registration marker is removed last by the successful install hook, including
a manual `nixos-rebuild switch` after an initial failure. Later switches and generation GC use
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

Successful managed NVMe boot and preserved generation roots were observed in the
acceptance above. Full registration → normal-unit ordering → managed builder →
cleanup, especially failure preservation/retry under injected faults, remains a
separate acceptance contract. Build and cleanup/topology tests do not prove fault
recovery, power-failure behavior or a real generation-deletion/GC cycle.

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
