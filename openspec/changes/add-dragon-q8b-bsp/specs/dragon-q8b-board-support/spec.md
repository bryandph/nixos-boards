## ADDED Requirements

### Requirement: Dragon Q8B named providers
The BSP SHALL default to a pinned Radxa kernel provider with a matching device tree. It SHALL expose a separately imported mainline experiment, clearly recording missing native board support without relabelling vendor device trees as mainline.

#### Scenario: Default provider
- **WHEN** the free fixture evaluates
- **THEN** its kernel and device tree use the same immutable Radxa source and provider warning.

### Requirement: Board-owned UEFI and sector-specific images
The BSP SHALL build UEFI GPT images for 512 and 4096-byte logical sectors, document a pinned board-owned UEFI baseline and recovery, and MUST NOT flash firmware automatically.

#### Scenario: Image creation
- **WHEN** a sector-specific image is built
- **THEN** both GPT header LBAs and FAT boot-sector geometry match the requested logical sector size.

### Requirement: Feature-scoped firmware licensing
Firmware with unestablished licensing SHALL remain blocked and never fetched. Firmware requiring operator acceptance SHALL only enter an explicitly imported operator-supplied feature.

#### Scenario: Missing DSP blobs
- **WHEN** no licensed DSP files have been imported
- **THEN** independent headless BSP support remains evaluable and unavailable DSP functions remain explicit gaps.

### Requirement: Evidence-based acceptance
The BSP SHALL expose public fixtures without remote credentials and document hardware results separately from evaluation/build verification.

#### Scenario: No physical access
- **WHEN** the BSP builds but has not booted on hardware
- **THEN** its functions remain implemented-unverified or blocked, not verified.
