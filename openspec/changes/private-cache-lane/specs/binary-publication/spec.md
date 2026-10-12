## MODIFIED Requirements

### Requirement: Private lane
The private cache MAY additionally receive artifacts and built packages whose manifest entries permit `private`. Artifacts and built packages without that permission MUST NOT be copied to any binary cache or to any machine other than the one that imported them and the board that runs the system built from them. Deploying a system to its board is use, not publication.

#### Scenario: Internal copy permitted
- **WHEN** an R2 artifact's license permits internal copies
- **THEN** it may be pushed to the private cache and never to the public one

#### Scenario: Deploying a system with R2 firmware
- **WHEN** a system that uses an R2 artifact without `private` is deployed to the board that runs it
- **THEN** the deployment is allowed, and the system's closure is not pushed to the private cache

## ADDED Requirements

### Requirement: Publication status
Every system that imports the board options SHALL expose a read-only `hardware.boards.publication.private` status and the list of artifacts that block it, computed from `hardware.boards.artifacts`. The repository SHALL provide a pre-push scan for the private lane that fails when a closure contains a file matching an artifact not cleared for `private`.

#### Scenario: Cache tooling meets a blocked system
- **WHEN** a system uses a built package derived from an R2 artifact without `private`
- **THEN** `hardware.boards.publication.private` is false and the blocking list names that package
