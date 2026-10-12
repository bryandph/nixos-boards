## 1. Providers and boot
- [x] Verify immutable repository bases and isolate BSP worktree.
- [x] Pin Radxa vendor source and record board-owned UEFI version.
- [x] Implement and evaluate core/vendor provider.
- [ ] Establish explicit experimental mainline DT contract.
- [ ] Build GPT UEFI images for 512/4096 logical sectors.

## 2. Licensing and profiles
- [x] Record exact artifact/license evidence on LAB-151 (immutable HEAD-only metadata; four supported R2 files).
- [x] Add provider manifests; unknown licensing remains blocked.
- [x] Add free/full fixtures and supported optional import features.

## 3. Documentation and verification
- [x] Generate docs/gaps/hardware matrix.
- [ ] Verify DT/provider, production images and complete boot reproducibility (kernel build in progress). Mock-input assembler layout and byte reproducibility checks pass for both sector sizes.
- [x] Run formatting, Nix, OpenSpec and docs checks (6 native aarch64-darwin checks + all 17 x86_64-linux checks pass; production aarch64 image/DT builds pending).
- [ ] Run required open-code-review and resolve findings (capability currently unavailable; coordinator sourcing route).
- [ ] Return PR/commits and exact results on LAB-152.

Physical boot/network/storage verification is pending operator access and must not be marked verified by builds alone. No merge/deploy/flash/closure is authorized.
