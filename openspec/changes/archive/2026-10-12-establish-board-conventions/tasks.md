## 1. Bootstrap

- [x] 1.1 Flake skeleton: flake-parts, import-tree, treefmt (`nix run .#fmt`), NixOS 26.05 lock, no devenv
- [x] 1.2 AGENTS.md, OpenSpec configuration and this change
- [x] 1.3 Wiki skeleton (`Home`, `_Sidebar`, `Glossary`) and `checks.wiki-links`
- [x] 1.4 Approval of this change's design and specs (maintainer; 2026-10-11, with the D2 namespace, D4 flashing tools and D12 upstream-first revisions)

## 2. Board options and manifests

- [x] 2.1 `modules/lib/hardware-boards.nix`: `hardware.boards.identity`, `hardware.boards.connectors`, `hardware.boards.claims`, `hardware.boards.artifacts` options and the claim-conflict assertion
- [x] 2.2 `modules/lib/library.nix` and `modules/lib/_boards-lib.nix`: typed release-manifest schema, R0–R2 classes, redistribution forms, `blocked: licensing` entries
- [x] 2.3 Helpers that build R1 fixed-output fetches and R2 `requireFile` derivations from manifest entries, with license files and `meta` filled from the entry
- [x] 2.4 Generated `lib.unfreePackages.<board>` and unfree predicates from manifests
- [x] 2.5 Synthetic test board under `modules/lib/_test/` exercising claims, all three classes and a blocked artifact (`checks.lib-*`)
- [x] 2.6 Guarded firmware-flashing helper (interactive-terminal check, manifest version and hash display, recovery text, typed board-name confirmation) with a test that it refuses non-interactive use, plus a Linux pty test of the confirmed write

## 3. Profiles and checks

- [x] 3.1 Fixture factory producing `<board>-free` (nixpkgs `allowUnfree = false`) and `<board>-full` (generated predicate) configurations (`modules/lib/library.nix`)
- [x] 3.2 Per-board checks: fixture assertions, manifest validation, provider consistency (`checks.<board>-free`, `checks.<board>-full`, `checks.release-manifests`; provider assertions and warning in `hardware-boards`)
- [x] 3.3 Gap-table generator grouped by layer
- [x] 3.4 Fixture checks on the test board: free fixture fails with an unfree dependency and evaluates with firmware nixpkgs counts as free; a feature's own `nixpkgs.config` fails; push set fails for an artifact not cleared for cache (conflicting claims are covered by `checks.lib-claims`)

## 4. Publication

- [x] 4.1 Push-set evaluation with the cache-permitted predicate
- [x] 4.2 Pre-push closure hash scan against non-cacheable manifest hashes, with a test that copies a blob under another name
- [x] 4.3 Opt-in consumer cache module for bph.cachix.org (`nixosModules`/`darwinModules.nixos-boards-cache`)
- [x] 4.4 Push workflow for the public lane (`.github/workflows/publish.yml`; pushes once the `CACHIX_AUTH_TOKEN` secret exists)

## 5. Documentation

- [x] 5.1 `nix build .#docs` generator for hardware matrices, firmware tables and gap tables
- [x] 5.2 Docs drift check naming the regeneration command
- [x] 5.3 `Guide-Adding-a-Board` and `Guide-Non-Free-Firmware` pages
- [x] 5.4 CI workflow mirroring `docs/wiki/` to the GitHub wiki from the default branch (`.github/workflows/wiki.yml`; runs once the wiki's first page exists)

## 6. CI and verification

- [x] 6.1 GitHub Actions: `nix flake check` on x86_64-linux and aarch64-linux (`.github/workflows/check.yml`); OpenSpec validation and actionlint run inside `nix flake check`
- [x] 6.2 Verify: `nix run .#fmt -- --fail-on-change`, `nix flake check`, `openspec validate --strict` (2026-10-11: all 14 checks on aarch64-darwin, aarch64-linux and x86_64-linux)
- [x] 6.3 Archive this change into `openspec/specs/` after approval and implementation
