# nixos-boards

nixos-boards provides NixOS board support for single-board computers,
modules and carriers. Every board follows the same conventions:

- One layout. Boards live in `modules/<vendor>/<board>`, SoC families in
  `modules/soc/<soc>`, and every feature is a composable NixOS module.
- Named kernel, device tree and firmware providers. Mainline comes first;
  vendor providers are opt-in and emit a warning.
- Licensing is established before any non-free artifact is packaged. A
  release manifest records the provenance and permitted redistribution of
  every artifact.
- A free profile with as much hardware support as free software allows,
  and a full profile that adds the non-free pieces. The gaps between the
  two are documented for every board.
- Only artifacts whose licenses permit it are published to the binary
  cache, `bph.cachix.org`. Import `nixosModules.nixos-boards-cache` to
  use it.

See the [Glossary](Glossary) for the terms used throughout this wiki.

## Status

The conventions are approved and the shared library is in place: board
options, release manifests, artifact packaging, free and full test
configurations, publication gates and generated documentation.

| Board | SoC | Profiles | Provider |
| --- | --- | --- | --- |
| [BeagleY-AI](BeagleY-AI) (BeagleBoard.org) | AM67A / J722S | free, full | `beagle-ti-6.12-psdk-11.02` |
| [FRDM-i.MX95](FRDM-i.MX95) (NXP) | i.MX 95 | free, full | `mainline`; `nxp-lf-6.18.20-2.0.0` |
| [uConsole](uConsole) (ClockworkPi, CM5) | BCM2712 | free | `rpi-<release>` |
| [Turing RK1](Turing-RK1) (Turing Machines) | RK3588 | free | `mainline` |
| [Orange Pi 5](Orange-Pi-5) (Xunlong) | RK3588S | free | `mainline` |
| [Orange Pi 5 Plus](Orange-Pi-5-Plus) (Xunlong) | RK3588 | free | `mainline` |
| [ROCK 5A](ROCK-5A) (Radxa) | RK3588S | free | `mainline` |
| [Dragon Q8B](Dragon-Q8B) (Radxa) | SC8280XP | free, full | `radxa-7.0.11` (mainline blocked) |

To contribute a board, start with [Adding a board](Guide-Adding-a-Board)
and [Non-free firmware](Guide-Non-Free-Firmware).

## Editing this wiki

This wiki is generated from `docs/wiki/` in the repository and mirrored by
CI. Edits made directly on GitHub are overwritten; open a pull request
instead.
