## 1. Bootstrap

- [x] 1.1 Flake skeleton: flake-parts, import-tree, treefmt (`nix run .#fmt`), NixOS 26.05 lock, no devenv
- [x] 1.2 AGENTS.md, OpenSpec configuration and this change
- [x] 1.3 Wiki skeleton (`Home`, `_Sidebar`, `Glossary`) and `checks.wiki-links`
- [x] 1.4 Approval of this change's design and specs (maintainer; 2026-10-11, with the D2 namespace, D4 flashing tools and D12 upstream-first revisions)

## 2. Board options and manifests

- [ ] 2.1 `modules/lib/boards.nix`: `hardware.boards.identity`, `hardware.boards.connectors`, `hardware.boards.claims`, `hardware.boards.artifacts` options and the claim-conflict assertion
- [ ] 2.2 `modules/lib/manifest.nix`: typed release-manifest schema, R0–R2 classes, redistribution forms, `blocked: licensing` entries
- [ ] 2.3 Helpers that build R1 fixed-output fetches and R2 `requireFile` derivations from manifest entries, with license files and `meta` filled from the entry
- [ ] 2.4 Generated `lib.unfreePackages.<board>` and unfree predicates from manifests
- [ ] 2.5 Synthetic test board under `modules/lib/_test/` exercising claims, all three classes and a blocked artifact
- [ ] 2.6 Guarded firmware-flashing helper (interactive-terminal check, manifest version and hash display, recovery text, typed board-name confirmation) with a test that it refuses non-interactive use

## 3. Profiles and checks

- [ ] 3.1 Fixture factory producing `<board>-free` (no unfree) and `<board>-full` (generated predicate) configurations
- [ ] 3.2 Per-board checks: fixture assertions, manifest validation, provider consistency
- [ ] 3.3 Gap-table generator grouped by layer
- [ ] 3.4 Negative checks on the test board: free fixture fails with an unfree dependency; conflicting claims fail; a hand-written allowlist entry fails

## 4. Publication

- [ ] 4.1 Push-set evaluation with the cache-permitted predicate
- [ ] 4.2 Pre-push closure hash scan against non-cacheable manifest hashes, with a test that copies a blob under another name
- [ ] 4.3 Opt-in consumer cache module (substituter and key set once the service is chosen)
- [ ] 4.4 Push workflow for the public lane, enabled only after the cache service decision

## 5. Documentation

- [ ] 5.1 `nix build .#docs` generator for hardware matrices, firmware tables and gap tables
- [ ] 5.2 Docs drift check naming the regeneration command
- [ ] 5.3 `Guide-Adding-a-Board` and `Guide-Non-Free-Firmware` pages
- [ ] 5.4 CI workflow mirroring `docs/wiki/` to the GitHub wiki from the default branch

## 6. CI and verification

- [ ] 6.1 GitHub Actions: `nix flake check` on x86_64-linux and aarch64-linux
- [ ] 6.2 Verify: `nix run .#fmt -- --fail-on-change`, `nix flake check`, `openspec validate --strict`
- [ ] 6.3 Archive this change into `openspec/specs/` after approval and implementation
