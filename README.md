# nixos-boards

NixOS board support for single-board computers, development kits, compute
modules and carriers.

This repository is being bootstrapped. Its conventions are being drafted as an
OpenSpec change. They cover:

- dendritic flake-parts layout: board, SoC-family and add-on features composed by imports;
- kernel / device-tree / firmware provider contracts, mainline first;
- boot-chain ownership classes;
- documented provenance and licensing for every non-free artifact, in R0
  (free), R1 (redistributable) and R2 (operator-supplied) classes;
- `free` and `full` profiles for each board, with documented gaps;
- binary-cache publication limited to content that may be redistributed;
- documentation authored in `docs/wiki/` and mirrored to the project wiki.

Licensing is established before any non-free artifact is adopted.

The MIT license covers original source code only. It does not cover
third-party firmware or vendor artifacts referenced by this repository.
