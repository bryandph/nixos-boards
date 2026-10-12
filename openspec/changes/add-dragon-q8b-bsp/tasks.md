## 1. Providers and boot
- [x] Verify immutable repository bases and isolate BSP worktree.
- [x] Pin Radxa vendor source and record board-owned UEFI version.
- [x] Implement and evaluate core/vendor provider.
- [x] Record operator decision: mainline blocked until compatible native DTS or reviewed backport; no factory-DT exception.
- [x] Build GPT UEFI images for 512/4096 logical sectors.

## 2. Licensing and profiles
- [x] Record exact artifact/license evidence on LAB-151 (immutable HEAD-only metadata; four supported R2 files).
- [x] Add provider manifests; unknown licensing remains blocked.
- [x] Add free/full fixtures and supported optional import features.

## 3. Documentation and verification
- [x] Generate docs/gaps/hardware matrix.
- [x] Build pinned vendor kernel and verify actual matching DT/provider contract.
- [x] Check actual 512/4096 images, GPT CRCs, FAT BPB, EFI loader, DT boot entry and ext4 root.
- [x] Byte-compare repeated actual rootfs creation and production boot-image assembly for both sectors. Fixed kernel/initrd/toplevel closure inputs; independent recompilation reproducibility is not claimed.
- [x] Run formatting, Nix, OpenSpec and docs checks.
- [ ] Run required open-code-review and resolve findings (ocr exists; review exits before LLM because intended endpoint is unconfigured; no auth/model/billing path changed).
- [x] Publish draft PR #6 and report evidence/remaining gates on LAB-152.

Physical boot/network/storage verification is pending operator access and must not be marked verified by builds alone. No merge/deploy/flash/closure is authorized.
