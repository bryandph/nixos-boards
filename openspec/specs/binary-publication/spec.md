# binary-publication Specification

## Purpose
Describes ordinary cache publication, explicit build targets, recorded provenance and opt-in cache configuration. The repository does not implement a license-derived publisher admission service, release approval variable or content scanner.

## Requirements
### Requirement: Explicit publication targets
CI SHALL use the board registry's explicit `publish` build attributes and `publishArtifacts` standalone artifact lists. Manifest license or redistribution flags MUST NOT automatically select, reject or add publication targets.

#### Scenario: A manifest's permission metadata changes
- **WHEN** recorded permission metadata changes without changing the configured build targets
- **THEN** the publication target list stays unchanged

### Requirement: Conventional CI authentication
Cache CI SHALL run after successful main-branch checks, or a normal manual invocation, using ordinary Cachix authentication. Wiki CI SHALL mirror main-branch documentation pushes after generated-doc and link checks, or a normal manual invocation using the repository token. No exact-SHA approval variable, pre-push scanner or separate publisher service SHALL be required.

#### Scenario: Successful main CI with publication authentication
- **WHEN** main-branch checks succeed and the normal cache credential is configured
- **THEN** the publisher builds and pushes the configured targets without a bespoke release-admission step

### Requirement: Retained provenance
Release manifests SHALL continue recording source identity, license evidence, notices and permitted redistribution. Free and full profiles, pinned-source checks and notice installation SHALL remain independent of publication target selection. Recording metadata does not itself grant additional rights.

#### Scenario: Operator reads an artifact's terms
- **WHEN** an operator inspects the manifest or generated firmware page
- **THEN** the recorded provenance and terms remain available without a publisher policy engine

### Requirement: Opt-in consumer cache configuration
The repository SHALL offer a module that adds the public cache's substituter and key. Board features MUST NOT import it.

#### Scenario: Consumer opts in
- **WHEN** a consumer imports the cache module
- **THEN** the public substituter and its key are added to the consumer's Nix settings
