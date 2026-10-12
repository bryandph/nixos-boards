## ADDED Requirements

### Requirement: Built packages
A package built from manifest artifacts or from other pinned non-free sources SHALL be declared as a built entry of the board's release manifest, with its license, license evidence when non-free, redistribution forms, layer, load method, features, the artifacts it is built from and a description of its other sources. Its class MUST be at least as restrictive as the class of every artifact it is built from. The package SHALL be named `<manifest>-<id>` and registered with `mkBuilt`, which takes its license from the manifest. Generated unfree lists, publication gates and documentation SHALL treat built packages like artifacts.

#### Scenario: Package built from an operator-supplied archive
- **WHEN** a built package lists an R2 artifact in `from` but declares class R1
- **THEN** manifest validation fails

#### Scenario: Built package in a full profile
- **WHEN** a full fixture installs a registered built package whose license nixpkgs marks non-free
- **THEN** the generated unfree predicate admits it by name, and the free fixture fails if it installs the same package

### Requirement: Operator import of R2 artifacts
Each board with R2 artifacts SHALL provide an operator-run import command that lists every R2 artifact with its license evidence and download location. It SHALL download nothing unless the operator passes `--accept-license`, and SHALL verify each file's size and sha256 against the release manifest before adding it to the Nix store.

#### Scenario: Import without accepting
- **WHEN** the operator runs the import command without `--accept-license`
- **THEN** it prints the terms and sources of the missing artifacts, downloads nothing and exits non-zero
