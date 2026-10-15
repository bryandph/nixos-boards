# BeagleY-AI

> Hardware results described here are historical observations, not fresh
> current-candidate acceptance. See [historical scope](BeagleY-AI-Hardware-Notes#historical-observation-scope);
> the generated hardware matrix retains conservative current status.

The [BeagleY-AI](https://www.beagleboard.org/boards/beagley-ai) (4 GB) uses
the TI AM67A (J722S): four Cortex-A53 cores, R5F cores, two C7x DSP/MMA
accelerators, a PowerVR Rogue GPU and the Wave5 video codec.

| | |
| --- | --- |
| Vendor | BeagleBoard.org |
| SoC | TI AM67A / J722S |
| Boot chain | `image`: R5 and A53 U-Boot stages with TF-A, OP-TEE and TI's TIFS and Device Manager firmware on the SD card's FAT partition |
| Provider | `beagle-ti-6.12-psdk-11.02`: BeagleBoard's 6.12 kernel with TI Processor SDK 11.02 firmware |
| Profiles | free (core, image, connector add-ons) and full (boot firmware, codec, GPU, Wi-Fi/BLE, vision, accelerators, camera, RegNet) |

Cold and warm SD boot, generation rollback, Gigabit Ethernet, CPU frequency
control and external RTC ordering have been exercised on the board. Wi-Fi and
Bluetooth initialize; the PowerVR stack reports hardware Vulkan, EGL and
OpenCL; E5010 JPEG and Wave5 H.264/H.265 passed pixel comparisons; the
source-compiled RegNet offloaded all nodes to each C7x core. The
[hardware matrix](BeagleY-AI-Hardware-Matrix) records each function's status,
and [hardware notes](BeagleY-AI-Hardware-Notes) the detailed results.

## Features

| Feature | Profile | Provides |
| --- | --- | --- |
| `beagley-ai-core` | free | Coordinated kernel, device tree, serial console, thermal policy, uncompressed firmware |
| `beagley-ai-image` | free | SD layout: ROM-compatible FAT boot partition, ext4 root, extlinux generations, SD identity guard |
| `beagley-ai-boot-bundle` | full | U-Boot, TF-A, OP-TEE, TIFS and Device Manager written to the boot partition |
| `beagley-ai-multimedia` | full | Wave5 codec firmware and video tools |
| `beagley-ai-gpu` | full | PowerVR kernel module, firmware, Mesa and Vulkan/OpenCL libraries |
| `beagley-ai-wireless` | full | CC3301 Wi-Fi/BLE firmware and Bluetooth initialization |
| `beagley-ai-vision` | full (R2) | Source-built 4 GB C7x/R5 vision firmware and reserved memory |
| `beagley-ai-accelerator-runtime` | full (R2) | Vision apps, TIDL and OSRT libraries and tools |
| `beagley-ai-camera` | full (R2) | ISP tools, IMX219 tuning and the camera-to-TIDL runner |
| `beagley-ai-regnet-model` | full (R2) | RegNetX-200MF compiled with TI's x86 TIDL tools |
| `beagley-ai-remoteproc-ipc` | full | IPC echo firmware for R5/C7x diagnostics (exclusive with vision) |
| `beagley-ai-full` | full | Every full feature above except IPC and RegNet |
| `beagley-ai-csi0-imx219`, `beagley-ai-csi1-imx219` | free | IMX219 camera connector routes |
| `beagley-ai-dsi-rpi-7inch`, `beagley-ai-oldi-lcd185` | free | Panel and bridge routes |
| `beagley-ai-header-gpio14-15`, `-uart1`, `-i2c-400khz`, `-spi0`, `-pwm14`, `-pwm12`, `-mcasp0` | free | 40-pin header routes |
| `beagley-ai-usb-gadget` | free | USB-C ACM/ECM peripheral role |

Header, connector and remote-processor features claim the pins, buses and
cores they use, so incompatible combinations fail evaluation. Features
marked R2 are built from files without a redistribution grant; see
[non-free firmware](BeagleY-AI-Firmware).

## Using it

```nix
imports = with inputs.nixos-boards.nixosModules; [
  beagley-ai-core
  beagley-ai-image
  beagley-ai-full # non-free; see below
];
```

The full features need the board's non-free packages admitted by name:

```nix
nixpkgs.config.allowUnfreePredicate = inputs.nixos-boards.lib.unfreePredicate "beagley-ai";
```

Before building the vision, accelerator, camera or RegNet features, import
the R2 files on every machine that builds them:

```console
nix run github:bryandph/nixos-boards#beagley-ai-import-artifacts
nix run github:bryandph/nixos-boards#beagley-ai-import-artifacts -- --accept-license
```

The first command lists the files and their terms; the second downloads,
verifies and imports them. The three reviewed TI tool/model downloads and
`model-tools` have separately recorded controlled private-copy permission.
The four Sandbox helpers permit controlled TI-target builder use only through
the explicit operator-accepted interpretation; they and all affected derived
outputs remain denied for public/private caches. This is not an express helper
grant and does not require each controlled builder to invent a new grant.
See [firmware](BeagleY-AI-Firmware) for exact per-entry forms.

Build the image (`beagleyAiSdImage` applies the FAT corrections the K3 ROM
needs; the generic `sdImage` does not):

```console
nix build .#nixosConfigurations.beagley-ai-full.config.system.build.beagleyAiSdImage
```

Without `beagley-ai-boot-bundle`, the image has no boot files; the board's
boot ROM then needs `tiboot3.bin`, `tispl.bin` and `u-boot.img` on the FAT
partition from elsewhere. Read [boot and recovery](BeagleY-AI-Boot-and-Recovery)
before writing a card.

## Checks

CI runs `checks.aarch64-linux.beagley-ai-*`: device tree, image layout, boot
structure and reproducibility, header and media profiles, IPC device tree
and the full composition (evaluation only). Checks that need R2 files or
build the full system are under
`legacyPackages.<system>.hardwareChecks.beagley-ai`.

## Topics

[Accelerator firmware](BeagleY-AI-Accelerator-Firmware) ·
[accelerator runtime](BeagleY-AI-Accelerator-Runtime) ·
[model compilation](BeagleY-AI-Model-Compilation) ·
[remote processors](BeagleY-AI-Remoteproc) ·
[multimedia](BeagleY-AI-Multimedia) · [wireless](BeagleY-AI-Wireless) ·
[expansion header](BeagleY-AI-Expansion) · [USB gadget](BeagleY-AI-USB-Gadget) ·
[USB host](BeagleY-AI-USB-Host) · [RTC](BeagleY-AI-RTC) ·
[CPU cooling](BeagleY-AI-CPU-Cooling) · [core diagnostics](BeagleY-AI-Core-Diagnostics)
