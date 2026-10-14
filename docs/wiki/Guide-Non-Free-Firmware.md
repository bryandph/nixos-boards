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
| `private` | Keeping internal copies on the maintainer's private infrastructure |

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

The public cache is `bph.cachix.org`. Publication is default-deny. The
`publish` and `wiki` workflows admit only the current `main` commit whose
full 40-character SHA exactly matches the operator-controlled repository
variable `PUBLIC_RELEASE_SHA`. Missing, malformed or mismatched approval
refuses release. Both native `check` matrix jobs must have succeeded for
that **same SHA** in a completed `main` push run; PR checks, skipped jobs,
older green runs superseded by failed retries, and arbitrary-ref manual
dispatches do not qualify. Actions are pinned to immutable revisions and
checkout uses the admitted SHA without persisted credentials.

A completed `check` workflow can trigger admission; a manual retry on
`main` passes the same gates, never bypasses them. Admission is checked
again immediately before the write. Approval is necessary, not a license
grant or a replacement for closure policy. Preparing these workflows does
not approve any commit or authorize publication. Keep the variable unset
until a separately authorized release; do not use PR-controlled inputs to
supply it. A new main SHA needs its own approval and successful checks.

Admission requires both native jobs in the selected run attempt's API
response. If a partial "re-run failed jobs" attempt does not include both,
admission refuses it; use "re-run all jobs" to produce complete evidence.
Partial-rerun API behaviour is not assumed or established by offline fixtures.

After admission, cache publication still requires both content gates:

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

R2 artifacts never leave the machine that imported them.

To use the cache, import `nixosModules.nixos-boards-cache` (or
`darwinModules.nixos-boards-cache`). It adds the substituter and its key.

The scan matches exact file contents. NixOS compresses firmware by default
(`hardware.firmwareCompression`), so compressed copies only match if their
hashes are recorded in `derivedHashes`. The evaluation gate is the primary
protection.
