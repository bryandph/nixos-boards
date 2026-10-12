# Adding a board

This guide walks through adding a board that follows the repository
conventions. Terms are defined in the [Glossary](Glossary). Licensing rules
for firmware are in [Non-free firmware](Guide-Non-Free-Firmware).

## 1. Check upstream first

If nixos-hardware or nixos-raspberrypi can accept the support, contribute it
there. This repository holds what upstream cannot take: vendor providers,
licensing-gated firmware, release manifests, profiles, test configurations
and board documentation. A board here may import an upstream module and add
those layers on top.

## 2. Lay out the files

| Path | Holds |
|------|-------|
| `modules/<vendor>/<board>/` | Feature modules and the registry entry |
| `modules/soc/<soc>/` | Support shared by boards with the same SoC (`soc-<soc>`) |
| `packages/<vendor>/<board>/` | Kernel, bootloader and other package expressions, and release manifests |

The board identifier is the product's common name, e.g. `dragon-q8b`. The
vendor appears in the path, not in feature names.

## 3. Write the core

Every board has `<board>-core` and `<board>-image`. The core imports
`hardware-boards`, declares the board's identity and provider, and selects
a kernel labelled with that provider:

```nix
# modules/radxa/dragon-q8b/core.nix
{config, ...}: let
  boardsLib = config.boards.lib;
  inherit (config.flake.modules) nixos;
in {
  flake.modules.nixos.dragon-q8b-core = {pkgs, ...}: {
    imports = [nixos.hardware-boards nixos.soc-sc8280xp];
    hardware.boards.identity = {
      board = "dragon-q8b";
      vendor = "radxa";
      soc = "sc8280xp";
      bootChain = "board";
      provider = "mainline+dragon-q8b";
    };
    boot.kernelPackages = pkgs.linuxPackagesFor (boardsLib.withProvider "mainline+dragon-q8b"
      (pkgs.callPackage ../../../packages/radxa/dragon-q8b/linux.nix {}));
  };
  flake.nixosModules.dragon-q8b-core = config.flake.modules.nixos.dragon-q8b-core;
}
```

The core asserts that the kernel's `passthru.provider` matches. A provider
that is not mainline produces a warning that links the board's status page.

Rules for every feature:

- Compose by imports. No `enable` options, `specialArgs` or `_module.args`.
- Never set `nixpkgs.config`. The test configurations reject it, and
  non-free allowances come only from release manifests.
- Add a `hardware.boards.claims` entry for every connector pin, bus address,
  interrupt line or remote processor the feature uses.
- Never write board-owned firmware from a module, activation script or
  service. See *Board-owned firmware* below.

## 4. Use firmware through the manifest

Non-free artifacts are built only with `mkArtifact`, from a release manifest
registered in `boards.manifests`:

```nix
{config, ...}: let
  boardsLib = config.boards.lib;
  manifest = config.boards.manifests.dragon-q8b-firmware;
in {
  flake.modules.nixos.dragon-q8b-audio = {pkgs, ...}: let
    adsp = boardsLib.mkArtifact {
      inherit pkgs manifest;
      id = "adsp";
    };
  in {
    hardware.firmware = [adsp];
    hardware.boards.artifacts = [adsp];
  };
}
```

Every artifact a feature installs must also be listed in
`hardware.boards.artifacts`. Documentation and publication gates read that
list.

## 5. Register the board

```nix
# modules/radxa/dragon-q8b/registry.nix
{config, lib, ...}: {
  boards.manifests.dragon-q8b-firmware =
    import ../../../packages/radxa/dragon-q8b/firmware.manifest.nix {inherit lib;};
  boards.registry.dragon-q8b = {
    page = "Dragon-Q8B";
    free = with config.flake.modules.nixos; [dragon-q8b-core dragon-q8b-image];
    full = [config.flake.modules.nixos.dragon-q8b-full];
    manifests = ["dragon-q8b-firmware"];
    publish = ["toplevel" "image"];
    haveHardware = true;
    functions.ethernet = {
      status = "pending";
      features = ["dragon-q8b-core"];
    };
  };
}
```

Registration produces:

- the `dragon-q8b-free` and `dragon-q8b-full` test configurations, plus
  checks that evaluate both completely;
- `lib.unfreePackages.dragon-q8b` and `lib.unfreePredicate "dragon-q8b"`
  for consumers;
- `legacyPackages.<system>.publicPushSet.dragon-q8b`;
- the generated wiki pages `Dragon-Q8B-Hardware-Matrix`,
  `Dragon-Q8B-Firmware` and `Dragon-Q8B-Free-vs-NonFree`.

The free configuration evaluates with nixpkgs that rejects every non-free
license and all binary firmware that is not genuinely free. If a free
feature pulls in non-free code, evaluation fails.

## 6. Document the board

Write the two hand-written pages: `<Page>` (overview, what works, how to
build the image) and `<Page>-Boot-and-Recovery`. Run `nix run
.#write-docs` to generate the rest. Add all five pages to `_Sidebar.md`.

Status words in the hardware matrix are exactly:

- `verified`, with a link to the evidence;
- `implemented-unverified`;
- `blocked` with a reason;
- `pending`.

Do not include private hostnames, addresses or serial numbers.

## 7. Board-owned firmware

For `bootChain = "board"`, firmware such as SPI-flash UEFI belongs to the
board. The Boot and Recovery page states the minimum version, the update
procedure and the recovery procedure. An operator-run writer can be built
with `mkFlashTool`. It refuses to run without an interactive terminal,
shows the firmware version and hash from the manifest, prints the recovery
procedure, and writes only after the operator types the board name.

## 8. Verify

```console
nix run .#fmt
nix run .#write-docs
nix flake check
nix build .#nixosConfigurations.<board>-free.config.system.build.toplevel
```

Record physical verification in the hardware matrix only after observing
it on hardware.
