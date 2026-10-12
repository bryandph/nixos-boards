Tracked as LAB-145 (subtask of the LAB-144 epic) in the maintainer's work tracker.

## Why

Board support for the maintainer's boards is spread across separate flakes
(BeagleY-AI, FRDM-i.MX95, Rockchip RK3588, uConsole, plus a nixos-hardware
fork). Each solved the same problems differently: where kernels and firmware
come from, how non-free firmware is allowed in, what a public fixture may
contain, and how the board is documented. Before boards move here, and before
the first new board (Radxa Dragon Q8B) is added, the shared rules need to be
written down once so every board follows them and checks can enforce them.

## What Changes

- Define the repository layout: board, SoC-family and add-on modules,
  feature naming, exports, packages and release manifests.
- Define the provider contract for kernel, device tree and firmware, and the
  three boot-chain classes.
- Define how non-free artifacts are admitted: license established first,
  classes R0–R2, a release manifest recording provenance for every artifact,
  and nothing packaged while its license is unknown.
- Define the free and full profiles, how the free profile is enforced, and
  the generated table of gaps between them.
- Define binary publication: what may enter a public cache, and the
  evaluation-time and pre-push gates that keep everything else out.
- Define documentation: `docs/wiki/` as the source of the GitHub wiki, the
  page taxonomy, the hardware acceptance vocabulary and the shared glossary.
- Define public fixtures and the checks every board carries.

## Capabilities

### New Capabilities

- `board-layout`: repository structure, feature naming and exports, add-on
  library and resource claims, public fixtures and required checks.
- `platform-providers`: kernel, device tree and firmware providers, and
  boot-chain classes.
- `nonfree-provenance`: non-free classes, release manifests, and free and
  full profiles.
- `binary-publication`: public and private cache lanes and their gates.
- `board-documentation`: wiki source and taxonomy, generated pages,
  acceptance vocabulary and glossary.

### Modified Capabilities

None; this is the repository's first change.

## Non-goals

- Migrating any existing board. Each migration is its own change.
- Bringing up the Radxa Dragon Q8B, or deciding the license status of its
  firmware.
- Choosing the public cache service or plan. The publication rules apply to
  whichever is chosen.
- Renaming types in the companion embedded firmware workspace; the glossary
  here is the target of that rename, not the rename itself.
- Supporting non-NixOS operating systems or non-Linux host processors.

## Impact

- New repository content: `modules/lib/` infrastructure (manifest option
  schema, unfree predicate, profile and publication checks, docs generator),
  `docs/wiki/`, CI for checks and the wiki mirror.
- Downstream: existing board flakes must conform when migrated; consumers
  switch inputs board by board.
- Licensing review becomes a prerequisite for packaging any non-free
  artifact.
