# FRDM-i.MX95: M7 remoteproc

The exported `frdm-imx95-m7-remoteproc` NixOS module adds the upstream
`fsl,imx95-cm7` remoteproc node to the mainline FRDM device tree. It is not
part of the default board composition, does not install or auto-start
firmware, and does not add an M7 payload to the boot container. When composed
through `frdm-imx95-all-features`, the reviewed NXP device tree supplies that
node directly and the module does not apply its mainline overlay.

M7 firmware is not part of this repository. Add a remoteproc-loadable ELF to
`hardware.firmware`; `frdm-imx95-m7-ctl start [FIRMWARE]` loads
`frdm-imx95/frdm-imx95-m7-smoke.elf` by default. The original MIT-licensed
Embassy-Rust smoke firmware is moving to the maintainer's embedded-rust
repository. NXP's release archive contains only a raw, licensed power-mode
demonstration binary (artifact `frdm-imx95.m7-power-mode-demo`); import it
with `nix run github:bryandph/nixos-boards#frdm-imx95-import-nxp-m7-power-mode-demo`
and build `legacyPackages.aarch64-linux.frdm-imx95.m7-power-mode-demo`. It is
installed outside `lib/firmware`, because Linux remoteproc requires ELF, and
serves as a U-Boot and debug compatibility reference. The corresponding
public BSD-3-Clause MCUXpresso source pointers are recorded in the release
mapping.

The smoke firmware executes M7-local wait-for-interrupt after every heartbeat,
with SysTick as its bounded wake source. Linux/SRTM coordination, System
Manager authorization, an A55 wake source, and recovery preconditions have
not been validated, so the public firmware exposes no A55 power command and
A55 control remains disabled.

The `frdm-imx95-m7-remoteproc` feature selects the System Manager policy that
assigns the M7 to Linux (`m7-remoteproc-lmm`) through its own boot container,
claims `remoteproc:m7`, and installs `frdm-imx95-m7-ctl`, a guarded lifecycle
and UART test tool. Test only from removable media; nothing starts the M7
automatically.

## Isolation trade-off

The selected `m7-remoteproc-lmm` System Manager patch moves the M7 logical
machine from the secure to the nonsecure domain, removes the secure-environment
constraint, and gives its Linux-controlled policy broad API, LMM and M7 power-
domain access. This is an intentional remoteproc handoff, not an isolation or
least-privilege guarantee. Do not run untrusted M7 firmware under this policy.
Consumer boot-container overrides must preserve that policy and contain no
preloaded M7 application; the feature asserts both conditions. Hardware
isolation and failure containment have not been physically validated here.
