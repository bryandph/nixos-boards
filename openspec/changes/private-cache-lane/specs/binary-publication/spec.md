## MODIFIED Requirements

### Requirement: Private lane
The licensee's internal infrastructure SHALL hold copies of non-free artifacts and built packages only in the forms their manifest entries permit:
- `build` covers copies on the licensee's own build machines while building. It is implied by `file` and `private`.
- `private` covers the licensee's private binary cache, which MUST serve only the licensee's own systems.

Artifacts and built packages without `build` MUST be built only on a machine that imported them itself. Artifacts and built packages without `private` MUST NOT be pushed to any binary cache. Neither form permits public redistribution. Deploying a system to its board is use, not publication. An operator's authorization never substitutes for a vendor's grant.

#### Scenario: Internal copy permitted
- **WHEN** an R2 artifact's license permits internal reproduction by the licensee
- **THEN** it may be built on the licensee's build machines and pushed to the private cache, and never to the public one

#### Scenario: License grants no internal copies
- **WHEN** an R2 artifact has no license grant, or its terms do not permit reproduction
- **THEN** its manifest entry permits neither `build` nor `private`, and systems using it are built only where the operator imported it

#### Scenario: Deploying a system with R2 firmware
- **WHEN** a system that uses an R2 artifact without `private` is deployed to the board that runs it
- **THEN** the deployment is allowed, and the system's closure is not pushed to the private cache

## ADDED Requirements

### Requirement: Publication status
Every system that imports the board options SHALL expose read-only `hardware.boards.publication.private` and `hardware.boards.publication.build` statuses, with the artifacts that block each, computed from `hardware.boards.artifacts`. The repository SHALL provide a pre-push scan for the private lane that fails when a closure contains a file matching an artifact not cleared for `private`. A built package SHALL NOT permit any redistribution form, or internal build copies, that some non-free artifact it is built from does not permit.

#### Scenario: Cache tooling meets a blocked system
- **WHEN** a system uses a built package derived from an R2 artifact without `private`
- **THEN** `hardware.boards.publication.private` is false and the blocking list names that package

#### Scenario: Build package broader than its inputs
- **WHEN** a built package permits `private` but one of its R2 inputs does not
- **THEN** manifest validation fails
