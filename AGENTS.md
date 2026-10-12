# AGENTS.md

Guidance for AI coding assistants working in this repository.

nixos-boards is public NixOS board support for single-board computers,
modules and carriers. The conventions are specified in `openspec/specs/`
(and, until archived, in the active change under `openspec/changes/`).
Shared hardware terms are defined in `docs/wiki/Glossary.md`; use them.

## Structure

- Every `.nix` file under `modules/` is one dendritic flake-parts module,
  auto-imported by import-tree. Paths containing `/_` are skipped.
- Boards live in `modules/<vendor>/<board>/`, SoC families in
  `modules/soc/<soc>/`, add-ons in `modules/addons/<kind>/<name>/`.
- Package expressions and release manifests live under `packages/`.
- Shared library functions (manifest schema, `mkArtifact`, unfree lists,
  claims, `mkFlashTool`) live in `modules/lib/_boards-lib.nix`; build
  non-free artifacts only through `mkArtifact`.
- Contribute hardware support upstream (nixos-hardware, nixos-raspberrypi)
  when upstream can take it; this repository holds the rest.
- Compose features by imports. Do not add feature `enable` gates,
  `specialArgs`, or `_module.args` injection into NixOS configurations.
- Never add operator identity, credentials, hostnames or SSH keys. Fixtures
  are public and have no remote login.

## Non-free artifacts

- Establish the license before packaging any non-free artifact. If it is
  not established, do not package it; record it as `blocked: licensing`.
- Record every artifact in its provider's release manifest: source, size,
  hash, license, evidence and permitted redistribution.
- Never auto-accept an EULA, never commit vendor binaries, and never
  publish an artifact the manifest does not clear for the binary cache.

## Commands

- `nix run .#fmt` formats; `nix flake check` runs the checks. This
  repository has no devenv, so `--impure` is never needed.
- Stage new files with `git add` before any flake evaluation.
- Linux outputs use configured Linux builders; do not cap concurrency.
- Board-owned firmware (SPI flash, eMMC boot partitions) is written only
  by operator-run, interactively confirmed tools, never by automation,
  activation or CI. Record physical verification separately from implemented
  support.

## Documentation

`docs/wiki/` is the source of the GitHub wiki; CI mirrors it. Link pages
by page name, e.g. `[Glossary](Glossary)`; `checks.wiki-links` verifies
those links.
