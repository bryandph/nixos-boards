# nixos-boards

nixos-boards provides NixOS board support for single-board computers,
modules and carriers. Every board follows the same conventions:

- One layout. Boards live in `modules/<vendor>/<board>`, SoC families in
  `modules/soc/<soc>`, and every feature is a composable NixOS module.
- Named kernel, device tree and firmware providers. Mainline comes first;
  vendor providers are opt-in and emit a warning.
- Non-free artifacts need established license evidence or a separately
  recorded, explicitly accepted R2 internal-build interpretation bounded to
  its target and controlled builders. That interpretation is not a vendor
  grant and never clears caching or redistribution. Release manifests record
  provenance and permitted forms.
- Free profiles follow nixpkgs' license semantics; full profiles add the
  board's additional non-free pieces. This is not a publication grant. The
  gaps between profiles are documented for every board.
- Ordinary CI publishes configured targets after successful main-push checks
  using normal authentication, without license-derived selectors or scanners.
  Import `nixosModules.nixos-boards-cache` to use `bph.cachix.org`.

See the [Glossary](Glossary) for the terms used throughout this wiki.

## Status

The conventions are approved and the shared library is in place: board
options, release manifests, artifact packaging, free and full test
configurations, ordinary CI and generated documentation.

| Board | SoC | Profiles | Provider |
| --- | --- | --- | --- |
| [BeagleY-AI](BeagleY-AI) (BeagleBoard.org) | AM67A / J722S | free, full | `beagle-ti-6.12-psdk-11.02` |
| [FRDM-i.MX95](FRDM-i.MX95) (NXP) | i.MX 95 | free, full | `mainline`; `nxp-lf-6.18.20-2.0.0` |
| [uConsole](uConsole) (ClockworkPi, CM5) | BCM2712 | free | `rpi-<release>` |

To contribute a board, start with [Adding a board](Guide-Adding-a-Board)
and [Non-free firmware](Guide-Non-Free-Firmware).

## Editing this wiki

This wiki is generated from `docs/wiki/` in the repository and mirrored by
CI. Edits made directly on GitHub are overwritten; open a pull request
instead.
