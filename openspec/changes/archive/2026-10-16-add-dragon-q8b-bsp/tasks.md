## 1. Providers and boot
- [x] Verify immutable repository bases and isolate BSP worktree.
- [x] Pin Radxa vendor source and record board-owned UEFI version.
- [x] Implement and evaluate core/vendor provider.
- [x] Record operator decision: mainline blocked until compatible native DTS or reviewed backport; no factory-DT exception.
- [x] Build GPT UEFI images for 512/4096 logical sectors.

## 2. Licensing and profiles
- [x] Record exact artifact/license evidence in the provider manifest (immutable HEAD-only metadata; four supported R2 files).
- [x] Add provider manifests; unknown licensing remains blocked.
- [x] Add free/full fixtures and supported optional import features.

## 3. Documentation and verification
- [x] Generate docs/gaps/hardware matrix.
- [x] Build pinned vendor kernel and verify actual matching DT/provider contract.
- [x] Check actual 512/4096 images, GPT CRCs, FAT BPB, EFI loader, DT boot entry and ext4 root.
- [x] Byte-compare repeated actual rootfs creation and production boot-image assembly for both sectors. Fixed kernel/initrd/toplevel closure inputs; independent recompilation reproducibility is not claimed.
- [x] Run formatting, Nix, OpenSpec and docs checks.
- [x] Retain independent opposite-model source/delta review through canonical `92579ee`, including all 17 Q8B source bodies and corrected check/evidence deltas; unchanged bodies carry by blob identity, not a new whole-source read or OCR endpoint invocation.
- [x] Publish draft PR #6 and report evidence/remaining gates to the maintainer.

- [x] Complete authorized bounded full-profile 512-sector NVMe headless acceptance: native vendor 7.0.11/DT boot, UART, one Ethernet link, ordinary managed warm reboots, early TPM devices without the 90-second delay, renewed growth hooks on the already-expanded filesystem, preserved generations and verified vendor-SD fallback/return.
- [x] Clean only proven owned temporary staging/transport material; preserve permanent identity, recovery media and generation roots.
- [x] Retain the reviewed public evidence-bookkeeping corrections and canonical generated-doc/link/private-identifier checks, including the dated consumer-versus-public-fixture scope.

See [public acceptance evidence](../../../docs/wiki/Dragon-Q8B-Boot-and-Recovery.md#headless-hardware-acceptance), historical public acceptance receipt 622e47f75dc9a3888cbd6b8f8c12231b17a3c2e2. Structural free/full 512/4096 image checks do not establish free-fixture or 4096-sector hardware boot. No cold-start/power-failure, independent kernel rebuild, uConsole or GPU/audio verification is claimed. Historical bounded activation is complete and is not permission for additional rollout, tracker completion or firmware flashing. This landing stage still needs its own bounded composition review, exact-head native CI and separate operator source/publication approval; prior source and integration-CI receipts are retained, not a waiver.
