# nixos-boards

NixOS board support for single-board computers, development kits, compute
modules and carriers.

Every board follows the same conventions:

- Boards live in `modules/<vendor>/<board>` and SoC families in
  `modules/soc/<soc>`. Each feature is a NixOS module, composed by imports.
- Kernel, device-tree and firmware sources are named providers. Mainline
  comes first where it supports the board; boards that still need a vendor
  provider say so on their wiki page, and vendor providers emit a warning.
- Licensing is established before any non-free artifact is adopted. A
  release manifest records each artifact's provenance, license class (R0
  free, R1 redistributable, R2 operator-supplied) and permitted
  redistribution.
- Each board has a free profile and, where non-free pieces exist, a full
  profile. The gaps between them are documented per board.
- Only artifacts whose licenses permit it are published to the public
  binary cache.

## Boards

| Board | SoC | Profiles |
| --- | --- | --- |
| ClockworkPi uConsole (CM5) | BCM2712 | free |
| BeagleBoard.org BeagleY-AI | AM67A / J722S | free, full |
| NXP FRDM-i.MX95 | i.MX 95 | free, full |
| Turing Machines Turing RK1 | RK3588 | free |
| Xunlong Orange Pi 5 | RK3588S | free |
| Xunlong Orange Pi 5 Plus | RK3588 | free |
| Radxa ROCK 5A | RK3588S | free |
| Radxa Dragon Q8B | SC8280XP | free, full |

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
    nixosConfigurations.rk1 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-boards.nixosModules.turing-rk1-core
        nixos-boards.nixosModules.turing-rk1-image
      ];
    };
  };
}
```

`nix flake show` lists every module. The `<board>-free` and `<board>-full`
entries under `nixosConfigurations` are reference configurations. CI
evaluates them and builds the checks that need no operator-supplied files,
and the publish workflow builds each board's public push set, which can
include free-profile system images. Full-profile system and image builds,
and checks that need R2 files, are hardware checks
(`legacyPackages.<system>.hardwareChecks` and `crossChecks`) that the
operator builds; public CI does not.

For a full profile, allow the board's non-free artifacts with its generated
predicate. R2 artifacts must be imported on the build machine first; the
board's Firmware wiki page lists them and the import commands.

```nix
nixpkgs.config.allowUnfreePredicate = nixos-boards.lib.unfreePredicate "dragon-q8b";
```

## Binary cache

CI publishes each board's public push set to `bph.cachix.org`: the free
profile's builds and the artifacts whose manifests clear them for the cache.
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
