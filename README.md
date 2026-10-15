# nixos-boards

NixOS board support for single-board computers, development kits, compute
modules and carriers.

Every board follows the same conventions:

- Boards live in `modules/<vendor>/<board>` and SoC families in
  `modules/soc/<soc>`. Each feature is a NixOS module, composed by imports.
- Kernel, device-tree and firmware sources are named providers. Mainline
  comes first where it supports the board; boards that still need a vendor
  provider say so on their wiki page, and vendor providers emit a warning.
- Non-free artifacts need established license evidence or a separately
  recorded, explicitly accepted R2 internal-build interpretation bounded to
  its target and controlled builders. That interpretation is not a vendor
  grant and never clears caching or redistribution. Release manifests record
  provenance, license class and permitted redistribution.
- Each board has a free profile and, where non-free pieces exist, a full
  profile. The gaps between them are documented per board.
- Publication uses explicitly configured targets; recorded terms remain
  the operator's responsibility.

## Boards

| Board | SoC | Profiles |
| --- | --- | --- |
| ClockworkPi uConsole (CM5) | BCM2712 | free |
| BeagleBoard.org BeagleY-AI | AM67A / J722S | free, full |

Each board's wiki page covers its hardware matrix, boot and recovery,
firmware, and free versus non-free gaps.

## Usage

Add the flake as an input and import a board's modules, for example:

```nix
{
  inputs.nixos-boards.url = "github:bryandph/nixos-boards";
  # Optional: share your nixpkgs. The boards are tested against the pinned one.
  # inputs.nixos-boards.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {nixpkgs, nixos-boards, ...}: {
    nixosConfigurations.beagley-ai = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-boards.nixosModules.beagley-ai-core
        nixos-boards.nixosModules.beagley-ai-image
      ];
    };
  };
}
```

`nix flake show` lists every module. The `<board>-free` and `<board>-full`
entries under `nixosConfigurations` are reference configurations. CI
evaluates them and builds the checks that need no operator-supplied files,
and ordinary publishing builds each board's configured output set, which can
include free-profile system images. Full-profile system and image builds,
and checks that need R2 files, are hardware checks
(`legacyPackages.<system>.hardwareChecks` and `crossChecks`) that the
operator builds; public CI does not.

For a full profile, allow the board's non-free artifacts with its generated
predicate. R2 artifacts must be imported on the build machine first; the
board's Firmware wiki page lists them and the import commands.

```nix
nixpkgs.config.allowUnfreePredicate = nixos-boards.lib.unfreePredicate "beagley-ai";
```

## Binary cache

Ordinary CI publishes configured outputs to `bph.cachix.org` after successful
main-push checks using normal authentication. The registry explicitly lists
free-fixture outputs and standalone artifact targets; license flags do not
select or reject them. No SHA approval, scanner or separate publisher service
is required. Recorded provenance and terms remain factual; internal-use
interpretations do not grant additional rights.
Import `nixosModules.nixos-boards-cache` (or
`darwinModules.nixos-boards-cache`) to add the substituter and its key.

## Documentation

The [wiki](https://github.com/bryandph/nixos-boards/wiki) is generated from
`docs/wiki/` and mirrored by CI; edit it with a pull request. Start with
[Adding a board](https://github.com/bryandph/nixos-boards/wiki/Guide-Adding-a-Board)
and [Non-free firmware](https://github.com/bryandph/nixos-boards/wiki/Guide-Non-Free-Firmware).
Design decisions and requirements are kept as OpenSpec specs in
`openspec/specs/`.

## License

The MIT license covers original source code only. It does not cover
third-party firmware or vendor artifacts referenced by this repository; their
licenses are recorded in each board's release manifest.
