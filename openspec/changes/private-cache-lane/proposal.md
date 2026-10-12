Tracked as LAB-153 (subtask of the LAB-144 epic) in the maintainer's work tracker.

## Why

The private lane (D8) was specified, but nothing told a consumer's cache
tooling which systems it may push. A fleet that builds every host and
copies the closures to its private cache would copy packages built from
operator-supplied (R2) files whose licenses permit no internal copies, such
as NXP's boot firmware or TI's TIDL tools. The rule that R2 artifacts never
leave the importing machine also needs to say that deploying a system to the
board that runs it is use, not publication.

## What Changes

- `hardware.boards.publication.{private,blocking}`: a read-only status per
  system, computed from `hardware.boards.artifacts`. A system is blocked when
  it uses a non-R0 artifact or built package not cleared for `private`.
- `lib.nonPrivateHashes` and `apps.private-cache-scan`: the pre-push file
  scan for the private lane.
- The private-lane requirement states what may be pushed and that
  deployment to the target board is allowed.

## Impact

- Library: `modules/lib/hardware-boards.nix`, `_boards-lib.nix`,
  `publication.nix`.
- Spec: `binary-publication`.
- Consumers: cache-push tooling should skip blocked systems and scan before
  pushing.
