## Context

The board flakes this repository replaces share a dendritic flake-parts
layout but diverge in everything else:

- Non-free allowlists are duplicated between package sets and fixtures.
- Some vendor code accepts EULAs automatically.
- One flake commits boot binaries.
- Kernel pins are copied between boards.
- Documentation ranges from a full article set to a single README.

The prior art reviewed was nixos-hardware, nixos-raspberrypi and nakato's
nixos-sbc. From nixos-sbc this design adopts:

- versioned image layouts;
- an add-on device library built on board-exported buses;
- stable MAC addresses derived from SoC identity;
- per-board status pages;
- an opt-in consumer cache module;
- a bill of materials.

It rejects nixos-sbc's:

- feature `enable` gates;
- `_module.args` injection;
- bootstrap images with a well-known root password;
- blanket refusal of vendor kernels;
- unfiltered caching.

Terms follow `docs/wiki/Glossary.md`.

## Goals / Non-Goals

**Goals:**

- One set of rules every board follows, enforced by checks where possible.
- A non-free artifact is never packaged, built into an image or published
  unless its license permits that specific form of redistribution.
- Every board has a free profile with as much hardware support as free
  software allows, and documents what only the full profile provides.
- Documentation is generated from the same data the build uses.

**Non-Goals:**

- See the proposal. In particular, no board is migrated by this change.

## Decisions

### D1. Layout and naming

Boards live in `modules/<vendor>/<board>/`, SoC families in
`modules/soc/<soc>/`, the add-on library in `modules/addons/<kind>/<name>/`,
and repository infrastructure in `modules/lib/`. Package expressions and
release manifests live in the same shape under `packages/`.

The board identifier is the product's common name, unique in the
repository: `beagley-ai`, `frdm-imx95`, `dragon-q8b`. The vendor appears in
the path, not in feature names, which keeps existing feature names stable
through migration.

Feature modules are published as `flake.modules.nixos.<name>`:

| Feature | Required | Purpose |
|---------|----------|---------|
| `<board>-core` | yes | Boot, kernel, device tree and console. Free unless the board cannot boot without non-free code. |
| `<board>-image` | yes | Bootable image for the board's boot-chain class. |
| `<board>-full` | when non-free artifacts exist | Imports every non-free feature whose license is established. |
| `<board>-<function>` | no | One hardware function, e.g. `beagley-ai-wireless`. |
| `<board>-<connector>-<device>` | no | Board-specific binding of an add-on, e.g. `beagley-ai-csi0-imx219`. |
| `soc-<soc>` | per SoC family | Shared SoC support imported by board cores. |
| `addon-<kind>-<name>` | no | Board-independent add-on support written against a connector standard. |

Every published feature is re-exported in `nixosModules`.

- *Alternative:* one module per board with `enable` options per feature,
  as in nixos-sbc. This was rejected because composition by imports is the
  repository's pattern, and enable gates hide which code a configuration
  actually evaluates.
- *Alternative:* the vendor in every feature name. This was rejected as
  noisy, and it would break existing consumers.

### D2. Board-level options

Infrastructure declares a small `boards` NixOS option namespace. These
options describe the board; none of them turns a feature on or off.

- `boards.identity`: board, vendor, SoC, and the boot-chain class.
- `boards.connectors.<name>`: the connector standard and its pinout
  binding to SoC buses, pins and signals.
- `boards.claims`: resource claims from features and add-ons. An assertion
  fails evaluation when two claims name the same resource.
- `boards.artifacts`: the manifest entries of every non-free artifact the
  configuration uses. This feeds the profile, cache and documentation
  checks.

### D3. Providers

A provider is a named, coordinated source for kernel, device tree and
firmware:

- `mainline`;
- `mainline+<series>` for a named out-of-tree patch series;
- `<vendor>-<release>` for a vendor tree.

Every kernel derivation carries `passthru.provider`. The board core asserts
that the kernel's provider matches the provider of its device tree and
firmware.

Mainline is preferred. A board whose working provider is not mainline uses
that provider in its core and emits a NixOS warning naming the provider and
pointing at the board's status page. Alternative providers are separate
features, `<board>-provider-<name>`.

Kernels shared by several boards (for example a pinned version required by
a cluster's networking stack) are defined once, at SoC or repository level,
never copied into each board.

- *Alternative:* refuse vendor kernels outright. This was rejected because
  several boards have no usable mainline support today, and a documented,
  warned vendor provider is better than no support.

### D4. Boot-chain classes

| Class | Firmware lives | Repository role | Example |
|-------|----------------|-----------------|---------|
| `image` | In the boot image | Builds it from source where possible; R1 blobs from manifest | BeagleY-AI, RK3588, i.MX95 |
| `vendor-partition` | A vendor firmware partition the OS updates | Installs it through the vendor's documented mechanism | Raspberry Pi |
| `board` | On-board storage (e.g. SPI flash UEFI) | Never writes it; documents the minimum version, update and recovery | Dragon Q8B |

Automation never writes board-owned firmware. Writing it is an
operator-performed procedure documented on the board's *Boot and Recovery*
page.

### D5. Non-free classes

| Class | Meaning | Packaging |
|-------|---------|-----------|
| R0 | Free license | Ordinary derivation |
| R1 | Non-free, redistribution permitted | Fixed-output fetch from a pinned upstream URL; size and hash verified; license and notice files installed; `meta.license` from the manifest; `sourceProvenance = binaryFirmware` |
| R2 | Non-free, operator must obtain it | `requireFile` with import instructions; `allowSubstitutes = false`; `preferLocalBuild = true`; never published |

There is no "unclear" class. If the license of an artifact is not
established, the artifact is not packaged. The manifest lists it as
`blocked: licensing`, and the features that need it are documented as gaps.

Licenses requiring acceptance are never accepted on the user's behalf. Such
an artifact is R2: the operator obtains it after accepting the terms.

Vendor binaries are never committed to the repository.

- *Alternative:* an R3 class for "probably redistributable". This was
  rejected because it moves the risk to the binary cache, where mistakes
  are public and hard to retract.

### D6. Release manifests

Each provider of non-free artifacts has a release manifest: a pure Nix
attribute set in `packages/<vendor>/<board>/` or `packages/soc/<soc>/`,
validated by an option-typed schema in `modules/lib/`.

The manifest records the pinned source, and for each artifact:

- the installed path;
- size;
- sha256;
- SPDX license or `LicenseRef-*`;
- class;
- evidence: a URL, the date it was retrieved, and where in the document
  the grant appears;
- the redistribution forms the license permits:
  - `file`: the unmodified file;
  - `image`: inside an aggregate disk image;
  - `cache`: as a binary-cache substitute;
  - `private`: internal copies on the maintainer's private infrastructure;
- how the artifact is loaded: firmware path, boot partition, remote
  processor, or userspace library;
- the features it enables.

Manifests are the single source for:

- the unfree package names each board exports (`lib.unfreePackages.<board>`);
- the public cache filters (D8);
- the generated documentation (D10).

Duplicated hand-written allowlists are not permitted.

- *Alternative:* TOML or JSON manifests. These were rejected because Nix
  attribute sets need no parser, can reference `lib.licenses`, and are
  type-checked by the module system.

### D7. Profiles

Every board has two public fixtures, `<board>-free` and `<board>-full`, as
`nixosConfigurations`:

- `<board>-free` imports every free feature and evaluates with
  `nixpkgs.config.allowUnfree = false` and no unfree predicate. A
  non-free dependency in a free feature fails evaluation.
- `<board>-full` adds `<board>-full` and uses the board's generated
  unfree predicate.

Support is described in four layers: boot firmware, kernel and device tree,
runtime firmware, and userspace. A board whose boot chain needs non-free
code still has a free profile for the layers above it. Its image documents
the boot firmware the operator must provide, or it relies on board-owned
firmware.

A gap table, generated from the manifests and the two fixtures, lists each
function available only in the full profile, the artifacts it needs, and
their classes.

NixOS modules cannot reliably set the consumer's unfree predicate, because
the consumer may pass in its own `pkgs`. Boards therefore export the list,
and consumers compose it.

### D8. Publication lanes

- **Public lane:** a public binary cache. The service and plan are not yet
  decided. It carries the closures of the free fixtures, plus R1 artifacts
  whose manifest entry permits `cache`, and the derivations that embed
  them only if the entry also permits `image`.
- **Private lane:** the maintainer's private cache. It carries everything
  above, plus artifacts whose entry permits `private`.

Two gates protect the public lane:

1. **Evaluation:** the set of outputs to publish is evaluated with an
   unfree predicate generated from the manifests that admits only
   cache-permitted names.
2. **Before push:** a scan computes the closure to be pushed. Every regular
   file in it is hashed and compared against the hashes of all manifest
   artifacts not cleared for `cache`. Any match fails the push.

Only outputs not already in the cache are pushed. R2 artifacts never leave
the machine that imported them.

The repository also offers an opt-in consumer module that adds the public
cache's substituter and key. It is never imported by board features.

### D9. Fixtures, identity and images

Public fixtures contain no credentials, SSH keys, hostnames tied to real
machines, or remote login. A local serial-console autologin is permitted
for bring-up. Passwords, including well-known default passwords, are not.

Boards whose network interfaces lack a factory-programmed MAC address
derive a stable address from a per-device SoC identifier. MAC addresses
are never hard-coded.

Image modules declare a layout version. A change to partitioning,
filesystem labels or boot-file placement increments the version and
documents the upgrade path.

### D10. Documentation

`docs/wiki/` is the source of the GitHub wiki, and CI mirrors it. Pages are
named in a flat namespace:

- `Home`, `_Sidebar`, `Glossary`;
- `Guide-*` for contributors and users;
- `SoC-*` for SoC families;
- `<Board>`, `<Board>-Hardware-Matrix`, `<Board>-Boot-and-Recovery`,
  `<Board>-Firmware`, `<Board>-Free-vs-NonFree`;
- `Research-*` for findings that are not yet support.

Hardware matrices, firmware tables and gap tables are generated by
`nix build .#docs` from manifests, `boards.*` options and fixtures, then
committed. A check fails when the committed pages differ from the generated
ones.

Hardware status uses four words:

- **verified:** observed working on hardware, with the evidence linked;
- **implemented-unverified:** built and evaluated, not yet observed on
  hardware;
- **blocked:** a named impediment, such as `blocked: licensing`;
- **pending:** not yet attempted.

Board pages list the hardware the maintainers have, so readers can tell
which verifications are possible. Documentation contains no private
hostnames, addresses or serial numbers.

### D11. Nixpkgs

The lock follows the current NixOS stable release branch. Consumers are
expected to set `inputs.nixpkgs.follows`. Kernel and firmware derivations
must not depend on unstable-only packages without a documented reason.

## Risks / Trade-offs

- **Licensing review slows adoption:** boards will ship with documented
  gaps instead of working firmware. This is accepted as the cost of a
  public cache that is safe to use.
- **Generated docs drift checks add friction:** regenerating docs is one
  command, and the check names it in its failure message.
- **File-hash push scanning misses transformed artifacts,** for example
  compressed or repacked blobs. Mitigation: the evaluation gate is primary;
  the manifest records derived forms (such as compressed firmware) as
  additional hashes where the build produces them.
- **`boards.claims` cannot see resources used outside this repository's
  modules.** This is accepted, and conflicts there are the consumer's to
  manage.

## Migration Plan

Each existing board migrates in its own change: BeagleY-AI, FRDM-i.MX95,
uConsole, the RK3588 boards, and the nixos-hardware fork's profiles. The
order is decided per change. Consumers switch inputs board by board, and
the old flakes are archived after their last consumer moves.

## Open Questions

- Which public cache service and plan to use. D8 applies to whichever is
  chosen.
- Whether boards already maintained upstream in nixos-hardware stay there,
  with this repository holding only the additions.
