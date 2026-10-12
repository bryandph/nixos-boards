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
Each board SHALL declare one boot-chain class: `image`, `vendor-partition` or `board`. For the `board` class, automation MUST NOT write board-owned firmware; the board's documentation SHALL state the minimum firmware version, the update procedure and the recovery procedure.

#### Scenario: Board-owned UEFI
- **WHEN** a board's firmware lives in on-board SPI flash
- **THEN** no package, activation script or app writes that flash, and the Boot and Recovery page documents the operator procedure
