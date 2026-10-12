# Glossary

These are the shared hardware terms for nixos-boards and its companion
embedded firmware workspace. Each term means the same thing in Linux board
support and in microcontroller firmware. Where a repository still uses an
older name, the *Also called* column lists it.

## Hardware

| Term | Meaning | Also called |
|------|---------|-------------|
| **Board** | A printed circuit board carrying at least one processor that runs software we build. A board is the unit nixos-boards supports. | SBC, devboard, `DevBoard` |
| **Module** | A board designed to plug into a carrier rather than run alone. It has the SoC, memory and usually storage, but few connectors. | SoM, compute module |
| **Carrier** | A board that hosts a module and provides its connectors, power and storage. A module on a carrier is supported as a single board. | baseboard, IO board |
| **Add-on** | A board without its own host processor that attaches to a board through a connector standard. Add-ons are portable across boards that share the connector standard. | `Hat` (embedded-rust, before the rename) |
| **Add-on kind** | The connector family of an add-on: `hat` (40-pin Raspberry Pi or Pico header), `pmod` (Digilent Pmod), `m2-card` (M.2 module), `camera` (MIPI CSI sensor module) or `panel` (DSI, LVDS or eDP display). | |
| **Connector standard** | A mechanical and electrical interface with a defined pinout, such as the 40-pin header, Pmod, M.2 key E, or a CSI-2 15-pin FFC. | form factor, `FormFactor` |
| **Pinout binding** | A board's mapping from a connector standard's pins to its SoC's buses, pins and signals. Add-ons are written against the connector standard, and the binding makes them concrete on one board. | |
| **Device** | A peripheral chip on a board or add-on, such as a sensor, PHY, codec, display controller or radio. | |
| **Claim** | A declaration that a feature or add-on uses a shared resource, such as a pin, bus address, interrupt or remote processor. Conflicting claims fail evaluation or compilation. | `PinClaims` (embedded-rust), resource claim |

## Processors

| Term | Meaning | Also called |
|------|---------|-------------|
| **SoC** | The system-on-chip at the center of a board: CPU cores, remote processors and on-chip peripherals. | chip, MCU (when it has no MMU) |
| **Host processor** | The processor that runs the board's main software: NixOS on a Linux board, the firmware application on a microcontroller board. | application processor, A-core |
| **Remote processor** | A secondary processor on the same SoC, managed by the host processor's operating system. Its firmware is loaded, started and stopped by the host. On Linux this is `remoteproc`. | coprocessor, M-core, R-core, DSP |

## Software

| Term | Meaning | Also called |
|------|---------|-------------|
| **OS BSP** | Board support for an operating system on the host processor. This repository is the NixOS OS BSP. | NixOS board support |
| **Firmware BSP** | Board support for firmware running without an operating system, or under an embedded executor, on a microcontroller or remote processor. | embedded BSP, `bsp-*` crate |
| **Platform layer** | The layer that abstracts an SoC's peripherals for software above it. In firmware this is a HAL; in Linux it is the kernel, its drivers and device tree. | HAL |
| **Provider** | A named, coordinated source for one platform layer, such as `mainline` or a vendor kernel release. Kernel, device tree and matching firmware come from the same provider. | |
| **Boot chain** | The sequence of firmware that runs before the operating system, and who owns it: the image, a vendor firmware partition, or the board itself. | |
| **Composition** | A selection of features that together describe one working system: a board, its add-ons and their claims. | stack |

## Licensing and publication

| Term | Meaning |
|------|---------|
| **Release manifest** | The pinned record of every artifact a provider ships: path, size, hash, license, evidence, permitted redistribution and what it enables. Profiles, cache filters and docs are derived from it. |
| **Free profile** | A board composition that evaluates with `allowUnfree = false`. |
| **Full profile** | The free profile plus every non-free artifact whose license has been established. |
| **R0, R1, R2** | Non-free classes: R0 is free; R1 is redistributable non-free firmware fetched from a pinned source; R2 is operator-supplied and never published. Artifacts whose license is not established are not packaged; they are listed as *blocked: licensing*. |
