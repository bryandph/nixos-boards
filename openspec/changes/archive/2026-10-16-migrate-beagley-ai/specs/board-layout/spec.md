## ADDED Requirements

### Requirement: Hardware checks outside CI
Checks that need R2 artifacts, or that build complete full-profile systems, SHALL NOT be flake checks. Boards SHALL expose them under `legacyPackages.<system>.hardwareChecks.<board>` so operators can run them after importing R2 artifacts.

#### Scenario: CI runs the flake checks
- **WHEN** CI runs `nix flake check` without any imported R2 artifact
- **THEN** no check fails for lack of an operator-supplied file
