# board-layout Specification

## Purpose
Defines how board support is organized in this repository: where board, SoC and add-on modules live, how features are named, composed and exported, the `hardware.boards` options that describe a board, the public test configurations every board has, and the checks every board must pass.
## Requirements
### Requirement: Repository layout
Board modules SHALL live in `modules/<vendor>/<board>/`, SoC-family modules in `modules/soc/<soc>/`, add-on library modules in `modules/addons/<kind>/<name>/`, and repository infrastructure in `modules/lib/`. Package expressions and release manifests SHALL live under `packages/` in the same shape. Every `.nix` file under `modules/` SHALL be a single flake-parts module of one kind: infrastructure, feature or configuration.

#### Scenario: Adding a board
- **WHEN** a contributor adds the Radxa Dragon Q8B
- **THEN** its features are in `modules/radxa/dragon-q8b/` and its packages and manifests are in `packages/radxa/dragon-q8b/`

### Requirement: Feature naming and exports
Each board SHALL publish `<board>-core` and `<board>-image` features, and SHALL publish `<board>-full` when it has any non-free artifact with an established license. Optional features SHALL be named `<board>-<function>` or `<board>-<connector>-<device>`. SoC features SHALL be named `soc-<soc>` and board-independent add-on features `addon-<kind>-<name>`. Every published feature SHALL be re-exported under `nixosModules`.

#### Scenario: Consumer imports a board
- **WHEN** a consumer imports `nixosModules.<board>-core` and `nixosModules.<board>-image`
- **THEN** the configuration evaluates to a bootable image for that board without any other feature

### Requirement: Composition without gates
Features SHALL be composed by imports. Repository modules MUST NOT declare `enable` options that switch their own features, MUST NOT use `specialArgs`, and MUST NOT inject `_module.args` into consumers' NixOS configurations.

#### Scenario: Review rejects an enable gate
- **WHEN** a change adds `options.hardware.boards.<board>.wireless.enable`
- **THEN** the change is rejected in favor of a separate `<board>-wireless` feature

### Requirement: Board description options
The repository SHALL provide `hardware.boards.identity`, `hardware.boards.connectors`, `hardware.boards.claims` and `hardware.boards.artifacts` NixOS options. Every board core SHALL set `hardware.boards.identity`, including its boot-chain class. Every feature that uses a pin, bus address, interrupt line or remote processor exposed through a connector SHALL add a claim. Evaluation SHALL fail when two claims name the same resource.

#### Scenario: Conflicting add-ons
- **WHEN** two add-on features both claim UART1's pins on the 40-pin header
- **THEN** evaluation fails with an assertion naming both features and the resource

### Requirement: Public fixtures
Each board SHALL have `<board>-free` and `<board>-full` fixture configurations (the latter only when `<board>-full` exists). Fixtures MUST NOT contain credentials, passwords, SSH keys, remote login, or identifiers of real machines. A local serial-console autologin MAY be used.

#### Scenario: Fixture image is built
- **WHEN** the free fixture's image is built and booted
- **THEN** it is reachable only through the local console, with no network login service enabled

### Requirement: Stable network identity
Boards whose network interfaces lack a factory-programmed MAC address SHALL derive a stable address from a per-device SoC identifier. MAC addresses MUST NOT be hard-coded.

#### Scenario: Two identical boards on one network
- **WHEN** two boards of the same model boot the same image
- **THEN** their derived MAC addresses differ and each is stable across reboots

### Requirement: Versioned image layout
Each image feature SHALL declare a layout version. Any change to partitioning, filesystem labels or boot-file placement SHALL increment the version and document the upgrade path.

#### Scenario: Partition layout changes
- **WHEN** a change moves the boot partition
- **THEN** the layout version increases and the board's Boot and Recovery page describes how to move existing installations

### Requirement: Required checks
Each board SHALL provide checks that evaluate both fixtures with no failed assertions, validate its release manifests, and verify its device tree contract. The repository SHALL provide formatting and documentation checks. Checks SHALL be runnable with `nix flake check` without `--impure`.

#### Scenario: Pull request verification
- **WHEN** a pull request changes a board
- **THEN** CI runs that board's checks and the repository checks, and a failure blocks merging

