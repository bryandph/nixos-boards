# Non-free firmware

Many boards need firmware or userspace binaries that are not free software.
This repository packages them only when their license allows it, records
where each comes from, and never publishes anything the license does not
permit. Terms are defined in the [Glossary](Glossary).

## Rules

1. **Establish the license first.** Read the license that actually
   applies, from the copyright holder. A packaging label is not enough.
   For example, a Debian `copyright` file that labels vendor blobs GPL does
   not count without a grant from the vendor. A separately recorded,
   evidence-backed operator-accepted internal-use interpretation may permit
   bounded R2 internal builds only (see below); it is not a vendor grant.
   Otherwise, if the license cannot be established, the artifact is not packaged. It is recorded as
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

- a recognized free SPDX license for R0; nixpkgs' special
  `unfreeRedistributableFirmware` profile allowance does not make an artifact R0;
- recorded license semantics for R1/R2 (a vendor firmware license may be
  permitted in nixpkgs' free profile but still needs R1 provenance/clearance);
- evidence for every non-free artifact;
- a pinned URL and at least one notice file for R1;
- import instructions for R2, which may never be publicly redistributable;
- `file` whenever `cache` is set;
- a reason on every blocked entry.

R2 does not waive notice obligations for internal copies. Preserve original
copyright/proprietary legends and install the applicable pinned notices.
Built entries can record `notices`; `mkBuilt` receives the consumer's `pkgs`
when fetching them and installs notices in every output, including `dev`.

## Redistribution forms

| Form | The license permits |
|------|---------------------|
| `file` | Redistributing the unmodified file |
| `image` | Including it in a disk image we distribute |
| `cache` | Publishing it as a binary-cache substitute |
| `private` | Copies in the licensee's private binary cache, served only to the licensee's own systems |
| `build` | Copies on the licensee's own build machines while building (implied by `file` and `private`) |

Set a form only when the license grants it.

### Separate internal-use interpretation

`internalUse` records explicit operator acceptance, a device/use target,
pinned source evidence, rationale and unresolved rights uncertainty. This is
not an express copyright-holder grant, does not set `redistribution.build`,
and must not promote the license to `redistributable=true`. Validation rejects
such a record unless it is R2 and all redistribution forms remain false.

For the four pinned BeagleY-AI TI Sandbox helpers, published TI-target use and
underlying TI source terms support the operator's accepted interpretation for
controlled internal builders producing J722S outputs. Independent rights for
the helper/wrapper text remain inferential; Debian package `Files:*` notices
do not clearly cover the root patches/scripts. Lack of a root LICENSE is not
by itself proof of unlawful use. The manifest and installed interpretation
notices retain this uncertainty. See [BeagleY-AI firmware](BeagleY-AI-Firmware).

Standalone helper source file/image/public/private-cache forms and every
affected derived output's file/image/public/private-cache forms remain denied.
The full profile retains its features; internal build eligibility is not cache
clearance. All `from` restrictions remain transitive, with no build-only input
exception. Runtime binaries, models, generated headers/DTS and dev contents
need a separate rights assessment and approved policy change before caching.
Unaffected established licensed outputs keep their existing permissions.

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

The public cache is `bph.cachix.org`. Conventional CI publishes the configured
build targets after successful main-branch checks, using its normal Cachix
authentication. `boards.registry.<board>.publish` names free-fixture build
outputs; `publishArtifacts` explicitly lists any standalone artifact targets.
License flags do not select the targets. There is no release-SHA approval
variable, permission-derived admission or pre-push content scanner.

The manifests still record source, license evidence, notices and permitted
redistribution. Free and full profiles retain their existing Nixpkgs behavior;
these profiles and metadata are not additional publication grants. Packaging
still checks pinned source integrity and installs its recorded notices. Cache
operators remain responsible for their use of the recorded terms.

To use the cache, import `nixosModules.nixos-boards-cache` (or
`darwinModules.nixos-boards-cache`). It adds the substituter and its public key.

Wiki CI mirrors `docs/wiki/` on main-branch documentation pushes after the
ordinary generated-doc and link checks. It can also be run manually with the
normal repository token. No separate publisher infrastructure is required.
