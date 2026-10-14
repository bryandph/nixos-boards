# Dragon Q8B BSP design

Scope: Dragon Q8B BSP implementation and evidence-backed artifact provenance/acquisition.

## Provider boundary

Default provider is radxa-7.0.11 from immutable radxa/kernel a50eb5b71984bd82b49cd5d31b1e2eb5505c6512. Kernel configuration and Q8B DT come from this source. The core imports the named provider, asserts the selected device-tree kernel package matches the selected kernel, and uses the maintained provider assertions/warning. There is no unrelated DT fetch or binary kernel adoption.

The mainline track is **blocked**, with no factory-UEFI-DT provenance exception. The mainline manifest records the missing compatible native DTS. Unblock through a compatible native DTS or reviewed source backport compiled with its matching pinned mainline kernel, DT/provider checks and a separate fixture; physical core verification follows. Missing mainline support does not gate the vendor BSP.

## Boot boundary

The BSP owns media, not the Qualcomm ROM/XBL/SPI boot chain. The observed UEFI banner is a versioned compatibility baseline, not a proven NixOS minimum. No UEFI payload is fetched and no implicit or explicit firmware writer is exported until licensing and exact payload provenance are established.

UEFI layout v1 has a 1 MiB-aligned, 512 MiB FAT32 ESP and ext4 root. Both GPT headers/entry CRCs and FAT BPB geometry use the requested logical sector size (512 or 4096). The ESP holds fallback BOOTAA64.EFI, systemd-boot entry, kernel/initrd and matching DTB. Actual EFI DT handoff/fixups, third-party OS settings and unsigned-image boot compatibility require physical acceptance. The fixture does not assume firmware preserves vendor dynamic DT mutations without verification.

The root filesystem imports the Nix closure and registration, supplies an init symlink and system profile, and registers paths on first boot before the daemon. A separate normally ordered first-boot unit then installs NixOS-managed generation entries, after store registration completes. Installation failure retains the bootstrap and retry marker without delaying registration. The post-install hook removes only the dedicated bootstrap entry/assets after a successful generation install, so switch/GC cannot leave an entry pointing to an unrooted closure. Partition growth is delegated to NixOS's existing growPartition implementation. Fixed GUIDs/labels describe installation fixtures, not machine identities; cloned images must not be mounted simultaneously by label without operator adjustment.

## Determinism and test scope

The assembler pins volume ID, partition/disk GUIDs and ESP timestamps. Rootfs staging timestamps and ext4 hash seed/lazy initialization are normalized. Both upstream copy anchors are guarded and hardlink preservation is disabled: NARs do not encode links, so builder store optimisation must not change the filesystem. The staging invariant rejects multiply linked regular files before mkfs; a controlled linked/unlinked source-topology test compares the resulting bytes. libext2fs otherwise picks signed/unsigned directory hashing from native C char defaults; a rootfs-only e2fsprogs override uses `-fsigned-char` before filesystem population. The installed system e2fsprogs is unchanged. An additional operator-only `legacyPackages.aarch64-linux.crossChecks.dragon-q8b-rootfs` proof constructs the same fixed ARM system closure using ARM and x86 tooling/stores, compares complete filesystem bytes, and requires healthy e2fsck results with zero inherited hardlinks. Run `nix build .#legacyPackages.aarch64-linux.crossChecks.dragon-q8b-rootfs --no-link` with both build platforms available; it is deliberately outside ordinary `checks` so single-architecture CI never requires a foreign builder. Mock-input tests execute the exact production rootfs helper twice and the exact image assembler twice for each sector size, comparing bytes. These establish builder determinism for fixed inputs, not independent reproducibility of the kernel/initrd/toplevel closure. Production image checks inspect actual boot-file presence, GPT CRCs, FAT sector geometry and ext4 root labels. Large rootfs/media constructors and reproduction checks declare `big-parallel` to use configured heavy builder lanes; there is no blanket job-count cap. Reproduction checks discard only their own completed staging trees/sector pairs to bound scratch disk usage. Hardware statuses remain implemented-unverified unless NixOS has actually been observed on the board.

## Firmware boundary

Only four licensed runtime candidates are adopted: Q8B ADSP and GPU SQE/GMU/Lenovo X13s ZAP. The vendor DTS explicitly reuses that ZAP; this does not authorize unrelated Lenovo firmware. All are pinned at linux-firmware ab23307cfe7f9366c819025ca3e4778299bc2db2 (20260916), with sizes and digests verified through HEAD-only metadata, no firmware download. Qualcomm terms require acceptance by use/installation, so the maintained operator-acceptance rule selects R2. Features use requireFile through mkArtifact, preserve notices, disable substitution/publication and allow internal copies only under the established grant. The operator personally reviews/accepts terms before acquisition/import; no agent accepts on their behalf.

Unknown vendor CDSP/QUP/video/topology and exact UEFI payload licensing remains blocked per feature, not as a blanket free-code gate. ADSP alone does not establish audio, and optional wireless/BT requires the actual card identity. No blanket radxa-firmware/linux-firmware collection enters the free closure.

