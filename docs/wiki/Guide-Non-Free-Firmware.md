# Non-free firmware

Many boards need firmware or userspace binaries that are not free software.
This repository packages them only when their license allows it, records
where each comes from, and never publishes anything the license does not
permit. Terms are defined in the [Glossary](Glossary).

## Rules

1. **Establish the license first.** Read the license that actually
   applies, from the copyright holder. A packaging label is not enough.
   For example, a Debian `copyright` file that labels vendor blobs GPL does
   not count without a grant from the vendor. If the license cannot be
   established, the artifact is not packaged at all. It is recorded as
   `blocked: licensing`, and the features that need it are documented as
   gaps.
2. **Never accept a license on the user's behalf.** Artifacts whose license
   requires acceptance are operator-supplied (R2). That includes installers
   with "accept" flags.
3. **Never commit vendor binaries** to the repository.
4. **Publish only what the license permits**, in the forms it permits.

## Classes

| Class | Meaning | How it is built |
|-------|---------|-----------------|
| R0 | Free license | Fetched from a pinned URL. |
| R1 | Non-free, redistribution permitted | Fetched from a pinned upstream URL. Size and hash are checked, and the license and notice files are installed. |
| R2 | Non-free, operator must obtain it | `requireFile`. Never substituted or published. The build prints how to obtain and import it. |

## Writing a manifest entry

Release manifests live in `packages/<vendor>/<board>/` and are registered
as `boards.manifests.<name>`. The values below are illustrative:

```nix
{lib}: {
  provider = "any";                 # or the kernel provider it must match
  version = "20260916";
  source = "linux-firmware 20260916";
  artifacts = {
    adsp = {
      class = "R1";
      url = "https://.../qcadsp8280.mbn";
      path = "lib/firmware/qcom/sc8280xp/radxa/dragon-q8b/qcadsp8280.mbn";
      size = 1234567;
      sha256 = "sha256-...";
      license = lib.licenses.unfreeRedistributableFirmware;
      evidence = {
        url = "https://.../WHENCE";
        retrieved = "2026-10-11";
        location = "qcom/sc8280xp/radxa entry";
      };
      notices = [{url = "https://.../LICENSE.qcom"; sha256 = "sha256-...";}];
      redistribution = {file = true; image = true; cache = true;};
      layer = "runtime-firmware";
      load = "firmware";
      features = ["dragon-q8b-audio"];
    };
    cdsp = {
      status = "blocked";
      blockedReason = "licensing";
      class = "R1";
      path = "lib/firmware/qcom/sc8280xp/radxa/dragon-q8b/qccdsp8280.mbn";
      layer = "runtime-firmware";
      load = "remoteproc";
      features = ["dragon-q8b-compute-dsp"];
    };
  };
}
```

`checks.release-manifests` validates every entry. It requires:

- a non-free license for R1 and R2;
- evidence for every non-free artifact;
- a pinned URL and at least one notice file for R1;
- import instructions for R2, which may never be publicly redistributable;
- `file` whenever `cache` is set;
- a reason on every blocked entry.

## Redistribution forms

| Form | The license permits |
|------|---------------------|
| `file` | Redistributing the unmodified file |
| `image` | Including it in a disk image we distribute |
| `cache` | Publishing it as a binary-cache substitute |
| `private` | Copies in the licensee's private binary cache, served only to the licensee's own systems |
| `build` | Copies on the licensee's own build machines while building (implied by `file` and `private`) |

Set a form only when the license grants it.

## Profiles

Each board has a free and a full test configuration. Both follow nixpkgs'
license semantics:

- The free configuration evaluates with `allowUnfree = false`, nixpkgs'
  default. nixpkgs counts `unfreeRedistributableFirmware` as free, so
  redistributable firmware can be part of the free profile, just as with
  NixOS's `hardware.enableRedistributableFirmware`.
- The full configuration admits exactly the board's manifest artifacts
  that nixpkgs marks unfree.

The classes above decide how an artifact is fetched and whether it may be
published. They do not change how nixpkgs treats its license.

Consumers allow a board's non-free artifacts with its generated predicate:

```nix
nixpkgs.config.allowUnfreePredicate = inputs.nixos-boards.lib.unfreePredicate "dragon-q8b";
```

## Publication

The public cache is `bph.cachix.org`. CI publishes to it from the default
branch after two gates pass:

1. **Evaluation.** The public push set,
   `legacyPackages.<system>.publicPushSet.<board>`, contains:
   - the free configuration's builds;
   - R1 artifacts cleared for `cache`, built with nixpkgs that admits only
     those names.

   It fails to evaluate if the free configuration installs any non-R0
   artifact that is not cleared for `cache`, or for `image` when images
   are published. This check reads the manifest rather than the license,
   because nixpkgs counts some non-free firmware as free.
2. **Pre-push scan.** `nix run .#cache-scan -- <store paths>` hashes every
   file in their closure. It refuses if any file matches a non-cacheable
   artifact, or one of its `derivedHashes`, from any manifest.

An R2 artifact leaves the machine that imported it only in the forms its
manifest entry permits, and never publicly. Internal build machines may hold
artifacts cleared for `build`, and the maintainer's private cache, serving
only the maintainer's own systems, may hold artifacts cleared for `private`.
Deploying a system to the board that runs it is always allowed. An
operator's authorization never replaces the vendor's grant: an artifact with
no license, or with terms that allow no reproduction, permits neither. Such
systems are built only where their files were imported, and
`config.hardware.boards.publication.build` is false for them.

Each system also reports whether its closure may go to the private cache:
`config.hardware.boards.publication.private` is false when the system uses
an artifact or built package not cleared for `private`, and
`config.hardware.boards.publication.blocking` names them. Cache tooling
should skip those systems and run `nix run .#private-cache-scan -- <paths>`
before pushing.

To use the cache, import `nixosModules.nixos-boards-cache` (or
`darwinModules.nixos-boards-cache`). It adds the substituter and its key.

The scan matches exact file contents. NixOS compresses firmware by default
(`hardware.firmwareCompression`), so compressed copies only match if their
hashes are recorded in `derivedHashes`. The evaluation gate is the primary
protection.
