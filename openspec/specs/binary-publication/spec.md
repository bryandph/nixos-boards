# binary-publication Specification

## Purpose
Defines what may be published to the public binary cache (`bph.cachix.org`) and the private cache, and the evaluation and pre-push gates that keep artifacts the licenses do not permit out of the public cache.
## Requirements
### Requirement: Public lane content
The public binary cache SHALL receive only the closures of free fixtures and outputs that contain no non-free artifact other than R1 artifacts whose manifest entries permit `cache`, and, for aggregate images, also `image`. R2 artifacts and artifacts not permitted for `cache` MUST NOT be pushed to the public cache.

#### Scenario: Firmware allowed as a file but not in a cache
- **WHEN** an R1 artifact permits `file` and `image` but not `cache`
- **THEN** outputs containing it are excluded from the public push set

### Requirement: Evaluation gate
The public push set SHALL fail to evaluate when a published configuration installs a non-R0 manifest artifact that is not permitted for `cache`, or for `image` when images are published. Cache-cleared R1 artifacts in the push set SHALL be built with nixpkgs that admits only cache-permitted package names.

#### Scenario: Firmware nixpkgs counts as free but not cleared for caches
- **WHEN** the free fixture installs an R1 artifact licensed `unfreeRedistributableFirmware` whose entry does not permit `cache`
- **THEN** evaluation of the push set fails and names the artifact

### Requirement: Pre-push content scan
Before pushing to the public cache, the publisher SHALL hash every regular file in the closure being pushed and compare the hashes with all manifest artifacts, and their recorded derived forms, that are not permitted for `cache`. Any match SHALL abort the push.

#### Scenario: Blob copied into an unrelated derivation
- **WHEN** a derivation copies a non-cacheable firmware file under another name
- **THEN** the scan matches its hash and the push is aborted

### Requirement: Private lane
The private cache MAY additionally receive artifacts whose manifest entries permit `private`. R2 artifacts without that permission MUST NOT leave the machine that imported them.

#### Scenario: Internal copy permitted
- **WHEN** an R2 artifact's license permits internal copies
- **THEN** it may be pushed to the private cache and never to the public one

### Requirement: Opt-in consumer cache configuration
The repository SHALL offer a module that adds the public cache's substituter and key. Board features MUST NOT import it.

#### Scenario: Consumer opts in
- **WHEN** a consumer imports the cache module
- **THEN** the public substituter and its key are added to the consumer's Nix settings

