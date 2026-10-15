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
configurations, ordinary CI and generated documentation.

| Board | SoC | Profiles | Provider |
| --- | --- | --- | --- |
| [uConsole](uConsole) (ClockworkPi, CM5) | BCM2712 | free | `rpi-<release>` |

To contribute a board, start with [Adding a board](Guide-Adding-a-Board)
and [Non-free firmware](Guide-Non-Free-Firmware).

## Editing this wiki

This wiki is generated from `docs/wiki/` in the repository and mirrored by
CI. Edits made directly on GitHub are overwritten; open a pull request
instead.
