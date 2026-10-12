Tracked as LAB-148 (subtask of the LAB-144 epic) in the maintainer's work tracker.

## Why

The BeagleY-AI is the first board to move here with a large non-free stack:
TI boot and connectivity firmware, the Processor SDK RTOS, x86 compilers,
TIDL tooling and a compiled model. Much of it is not a single firmware file
but a package built from SDK archives, tools and TI-licensed source
repositories. The conventions cover fetched artifacts only, so built
packages would escape the generated unfree lists and the publication gates.
Some inputs (the TIDL tools archive, the RegNet model, the `tidlruntime`
wheel, and patches and scripts from a repository without a license) have no
established redistribution grant and must be operator-supplied.

## What Changes

- Release manifests gain **built packages**: packages built from manifest
  artifacts or other pinned sources. Each has its own license, evidence and
  redistribution forms, and a class at least as restrictive as its inputs.
  `mkBuilt` attaches the manifest entry to an existing derivation without
  changing it, so built packages enter the unfree lists, the push-set gate
  and the generated pages like artifacts.
- A generic **R2 import tool** (`mkImportTool`, exposed per board as
  `apps.<board>-import-artifacts`). It shows each R2 artifact's terms and
  downloads, verifies and adds files only after `--accept-license`.
- Checks that need R2 inputs cannot run in CI. Boards expose them under
  `legacyPackages.<system>.hardwareChecks.<board>`.
- Migrate the BeagleY-AI (TI AM67A/J722S) from `nixos-beagley-ai`, with
  every non-free input classified after a licensing review (recorded on
  LAB-148).

## Impact

- Library: manifest type, validation, unfree lists, documentation pages and
  publication gates (`modules/lib/_boards-lib.nix`).
- Specs: `nonfree-provenance` (built packages, import tool) and
  `board-layout` (hardware checks).
- New board: `modules/beagleboard/beagley-ai/`, `packages/beagleboard/beagley-ai/`,
  `modules/soc/am67a/`.
