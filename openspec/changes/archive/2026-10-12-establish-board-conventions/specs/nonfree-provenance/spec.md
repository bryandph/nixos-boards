## ADDED Requirements

### Requirement: License established before packaging
A non-free artifact MUST NOT be packaged until its license has been established from evidence recorded in a release manifest. An artifact without an established license SHALL be listed in the manifest as `blocked: licensing` and SHALL NOT be fetched by any derivation.

#### Scenario: Vendor firmware with a contradictory license label
- **WHEN** a vendor package labels proprietary firmware with a free license and no grant from the copyright holder is found
- **THEN** the firmware is recorded as `blocked: licensing`, no derivation fetches it, and the features needing it are documented as gaps

### Requirement: Non-free classes
Every artifact SHALL be classed R0 (free), R1 (non-free with permitted redistribution) or R2 (non-free, operator-supplied). R0 artifacts SHALL have a license nixpkgs marks free, and R1 artifacts a license nixpkgs marks redistributable. R1 artifacts SHALL be fixed-output fetches from a pinned upstream URL, install their license and notice files, and carry `meta.license` and `meta.sourceProvenance` from the manifest. R2 artifacts SHALL use `requireFile` with import instructions, `allowSubstitutes = false` and `preferLocalBuild = true`.

#### Scenario: Operator-supplied firmware
- **WHEN** a build needs an R2 artifact that has not been imported
- **THEN** the build stops with instructions for obtaining and importing it

### Requirement: No implicit acceptance or committed binaries
The repository MUST NOT accept a license on the user's behalf, including through installer flags. Artifacts whose license requires acceptance SHALL be R2. Vendor binaries MUST NOT be committed to the repository.

#### Scenario: Self-extracting vendor archive
- **WHEN** a vendor ships firmware in an archive whose extractor requires accepting an EULA
- **THEN** the artifact is R2 and the operator runs the extractor themselves

### Requirement: Release manifests
Each provider of non-free artifacts SHALL have a release manifest recording its pinned source and, per artifact, the installed path, size, sha256, license, class, evidence (URL, retrieval date, location of the grant), permitted redistribution forms (`file`, `image`, `cache`, `private`), load method, and enabled features. Manifests SHALL be validated against a typed schema. The unfree package names each board exports SHALL be generated from its manifests.

#### Scenario: Hand-written allowlist
- **WHEN** a change adds an unfree package name to a fixture without a manifest entry
- **THEN** the manifest check fails

### Requirement: Free and full profiles
Profiles SHALL follow nixpkgs' license semantics. Each board's free fixture SHALL evaluate with `allowUnfree = false` and no unfree predicate. Board features MUST NOT set `nixpkgs.config`. Artifacts built from manifests SHALL carry their manifest license in `meta` unchanged, and generated unfree lists SHALL contain exactly the artifacts whose license nixpkgs marks non-free. Each board's full fixture SHALL use only the board's generated unfree predicate. The repository SHALL generate, per board, a table of functions available only in the full profile, with the artifacts and classes they require, grouped by layer: boot firmware, kernel and device tree, runtime firmware, userspace.

#### Scenario: Non-free dependency leaks into a free feature
- **WHEN** a feature imported by the free fixture depends on an unfree package
- **THEN** the free fixture fails to evaluate

#### Scenario: nixpkgs firmware marked free
- **WHEN** a feature imported by the free fixture adds firmware licensed `unfreeRedistributableFirmware`
- **THEN** the free fixture evaluates, as it would in nixpkgs, and publication is still governed by the artifact's manifest entry
