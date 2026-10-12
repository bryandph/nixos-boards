## ADDED Requirements

### Requirement: Named providers
Every kernel derivation SHALL carry `passthru.provider` with a provider name of the form `mainline`, `mainline+<series>` or `<vendor>-<release>`. A board core SHALL assert that its kernel, device tree and firmware come from the same provider.

#### Scenario: Mismatched device tree
- **WHEN** a configuration combines a mainline kernel with a vendor device tree package
- **THEN** evaluation fails with an assertion naming both providers

### Requirement: Mainline preference with warned vendor providers
A board core SHALL use the mainline provider when it supports the board's core functions. When it does not, the core SHALL use the working provider and emit a NixOS warning naming the provider and the board's status page. Alternative providers SHALL be separate `<board>-provider-<name>` features.

#### Scenario: Board needs a vendor kernel
- **WHEN** a configuration imports a core whose provider is `ti-<release>`
- **THEN** evaluation succeeds and prints a warning naming the vendor provider

### Requirement: Shared kernels are defined once
A kernel used by more than one board SHALL be defined once at SoC or repository level and referenced by each board.

#### Scenario: Two RK3588 boards need the same pinned kernel
- **WHEN** two boards require the same kernel version
- **THEN** both reference one definition, and updating it changes both

### Requirement: Boot-chain classes
Each board SHALL declare one boot-chain class: `image`, `vendor-partition` or `board`. For the `board` class, the board's documentation SHALL state the minimum firmware version, the update procedure and the recovery procedure.

#### Scenario: Board-owned UEFI
- **WHEN** a board's firmware lives in on-board SPI flash
- **THEN** the Boot and Recovery page documents its minimum version, update and recovery

### Requirement: Board firmware is written only by an operator
Board-owned firmware MUST NOT be written by activation, `nixos-rebuild switch`, boot services, CI, or any module imported implicitly. A board MAY provide an operator-run host tool `<board>-flash-firmware` and an operator-run on-device update command where the vendor supports one. Each tool SHALL refuse to run without an interactive terminal, SHALL show the target device and the firmware version and hash from the release manifest, SHALL print the recovery procedure, and SHALL write only after the operator types the board name. The firmware SHALL come from the board's release manifest.

#### Scenario: Non-interactive invocation
- **WHEN** `nix run .#<board>-flash-firmware` runs without a terminal, for example in CI
- **THEN** it exits without writing anything

#### Scenario: Operator flashes firmware
- **WHEN** the operator runs the tool interactively and types the board name
- **THEN** it writes the manifest-pinned firmware after showing its version, hash and the recovery procedure

### Requirement: Upstream first
Hardware support that nixos-hardware or nixos-raspberrypi can accept SHALL be contributed there. This repository SHALL hold only what upstream cannot take, and MAY import upstream modules and add providers, manifests, profiles, fixtures and documentation on top.

#### Scenario: Generic x86 machine profile
- **WHEN** a contributor proposes a profile for an x86 machine with no board-specific boot chain or licensing-gated firmware
- **THEN** it is directed to nixos-hardware instead
