Tracked as LAB-148 (subtask of the LAB-144 epic) in the maintainer's work tracker.

## Why

The BeagleY-AI is the first board to move here with a large non-free stack:
TI boot and connectivity firmware, the Processor SDK RTOS, x86 compilers,
TIDL tooling and a compiled model. Much of it is not a single firmware file
but a package built from SDK archives, tools and TI-licensed source
repositories. The conventions cover fetched artifacts only, so built
packages would escape the generated unfree lists and the publication gates.
The TIDL tools archive, RegNet model and `tidlruntime` wheel are
operator-supplied with separately established upstream terms and installed
notices. Four pinned TI Sandbox patches/helpers remain operator-supplied:
their independent source/helper grant remains inferential, despite published
TI-target use and relevant TI source-header/package license evidence. The
operator accepts only documented internal TI-target use and controlled
builder copies, not standalone redistribution or affected output caching.

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

## Internal-build-only closeout

- Manifests record an explicit `internalUse` interpretation separately from
  license grants: acceptance, TI-device/use boundary, pinned evidence,
  rationale and unresolved uncertainty. It does not set licensed `build` or
  license `redistributable=true`.
- All four helper standalone forms and all eight affected derived-package
  file/image/public/private-cache forms remain denied. Unaffected established
  licensed outputs retain their existing eligibility.
- All input restrictions remain transitive; no build-only/incorporated-input
  distinction or blanket output clearance is introduced. Generated headers,
  device trees, models and runtime/dev contents need separate assessment before
  any future caching decision.
- Interpretation notices accompany helper and affected package outputs and
  generated documentation. Fail-closed regressions verify acceptance/evidence,
  propagation, denied cache forms and unaffected grants. Full features remain.

## Impact

- Library: manifest type, validation, unfree lists, documentation pages and
  publication gates (`modules/lib/_boards-lib.nix`).
- Specs: `nonfree-provenance` (built packages, import tool) and
  `board-layout` (hardware checks).
- New board: `modules/beagleboard/beagley-ai/`, `packages/beagleboard/beagley-ai/`,
  `modules/soc/am67a/`.
