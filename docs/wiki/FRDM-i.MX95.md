# FRDM-i.MX95

The [NXP FRDM-i.MX95](https://www.nxp.com/design/design-center/development-boards-and-designs/FRDM-IMX95)
(15×15 mm package, LPDDR4X) uses the i.MX 95: six Cortex-A55 cores, a
Cortex-M7 and the Cortex-M33 System Manager, a Mali-G310 GPU, the Wave6 VPU
and the Neutron NPU.

| | |
| --- | --- |
| Vendor | NXP |
| SoC | i.MX 95 (B0) |
| Boot chain | `image`: an NXP boot container (U-Boot, TF-A, OP-TEE, System Manager, OEI and NXP's ELE and DDR firmware) at 32 KiB on the boot medium |
| Providers | `mainline` (Linux 7.0 or newer, upstream device tree); `nxp-lf-6.18.20-2.0.0` for the Wave6, combined and reference kernels; `mainline+neutron` for the reduced Neutron kernel |
| Profiles | free (mainline kernel, image layout, open GPU and JPEG, NVMe) and full (boot container, M7, Neutron, Wave6, audio, combined NXP kernel) |

The previous standalone repository booted the source-assembled boot
container on the board, and ran the M7, GPU, JPEG, Wave6 and Neutron
procedures below from removable media. The [hardware matrix](FRDM-i.MX95-Hardware-Matrix)
lists the status of each function.

## Features

| Feature | Profile | Provides |
| --- | --- | --- |
| `frdm-imx95-core` | free | Mainline kernel and the upstream `freescale/imx95-15x15-frdm.dtb`, `ttyLP0` console, extlinux |
| `frdm-imx95-image` | free | SD and eMMC image layout (layout version 1); the boot container comes from `hardware.boards.imx95.bootContainer` |
| `frdm-imx95-multimedia` | free | Open Mesa GPU (Panthor, PanVK) and V4L2 JPEG, with hardware probes |
| `frdm-imx95-nvme` | free | PCIe/NVMe tools and a read-only probe |
| `frdm-imx95-boot-container` | full (R2) | The source-assembled boot container with NXP's ELE and LPDDR4X firmware |
| `frdm-imx95-m7-remoteproc` | full (R2) | M7 under Linux remoteproc: System Manager policy, `fsl,imx95-cm7` node, `frdm-imx95-m7-ctl` |
| `frdm-imx95-wave6-vpu` | full (R2) | Wave6 H.264/HEVC on the NXP reference kernel with NXP's codec firmware |
| `frdm-imx95-neutron-npu` | full (R2) | Neutron runtime, TensorFlow Lite delegate, converted smoke model, acceptance smoke |
| `frdm-imx95-audio` | free with the combined kernel | MICFIL/MQS audio tooling and a probe |
| `frdm-imx95-all-features` | full | One combined NXP LF kernel and device tree for every feature above |
| `frdm-imx95-full` | full | All of the above |

Features that need NXP's licensed files are R2: every file is imported by
the operator after accepting NXP's license. Only the manifest-recorded
controlled internal/private forms are permitted; no public cache or
standalone redistribution is cleared. See [firmware](FRDM-i.MX95-Firmware).

## Using it

```nix
{
  imports = with inputs.nixos-boards.nixosModules; [
    frdm-imx95-core
    frdm-imx95-image
    frdm-imx95-boot-container # non-free; see below
  ];
  nixpkgs.config.allowUnfreePredicate = inputs.nixos-boards.lib.unfreePredicate "frdm-imx95";
}
```

Import NXP's files once on each machine that builds the board. Each command
verifies the release-pinned distribution and adds only the pinned files:

```console
nix run github:bryandph/nixos-boards#frdm-imx95-import-artifacts
nix run github:bryandph/nixos-boards#frdm-imx95-import-nxp-firmware -- --accept-license \
  firmware-ele-imx-2.0.6-c0b284c.bin firmware-imx-8.32-1991416.bin
```

The first lists every R2 file, its terms and how to obtain it. The other
imports, for the Wave6 firmware, the Neutron runtime, the converter SDK and
the M7 demonstration binary, are on the [firmware](FRDM-i.MX95-Firmware)
page.

The assembled boot container depends on the toolchain, so its accepted
identity is recorded per nixpkgs revision. A consumer on another revision
sets `hardware.boards.imx95.sourceBootContainerSha256` (and
`m7BootContainerSha256`) to the identity it has accepted; a mismatch fails
the build.

Build the image with `config.system.build.frdmImx95SdImage`, not the generic
`sdImage`, which lacks the boot container and environment. Read
[boot and recovery](FRDM-i.MX95-Boot-and-Recovery) before writing a card.

## Checks

CI runs `checks.aarch64-linux.frdm-imx95-*`: provider and image evaluation,
the required device tree, fail-closed firmware and provider validation, the
GPU, JPEG, Wave6 and Neutron module policies, and script tests. Checks that
need NXP's files or build an NXP kernel are in
`legacyPackages.aarch64-linux.hardwareChecks.frdm-imx95`, including the boot
container structure and reproducibility and the SD-image layout.

## Topics

[Multimedia and Wave6](FRDM-i.MX95-Multimedia) ·
[Neutron NPU](FRDM-i.MX95-Neutron) · [M7 remoteproc](FRDM-i.MX95-M7) ·
[boot and recovery](FRDM-i.MX95-Boot-and-Recovery)
