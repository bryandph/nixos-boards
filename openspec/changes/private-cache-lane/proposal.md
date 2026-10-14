Public change: controlled private-cache lane.

## Why

The private lane (D8) was specified, but nothing told a consumer's cache
tooling which systems it may push. A fleet that builds every host and
copies the closures to its private cache would copy packages built from
operator-supplied (R2) files whose licenses permit no internal copies, such
as NXP's boot firmware or TI's TIDL tools. The rule that R2 artifacts never
leave the importing machine also needs to say that deploying a system to the
board that runs it is use, not publication.

## What Changes

- `hardware.boards.publication.{private,blocking}`: a read-only status per
  system, computed from `hardware.boards.artifacts`. A system is blocked when
  it uses a non-R0 artifact or built package not cleared for `private`.
- `lib.nonPrivateHashes` and `apps.private-cache-scan`: the pre-push file
  scan for the private lane.
- The private-lane requirement states what may be pushed and that
  deployment to the target board is allowed.

## Impact

- Library: `modules/lib/hardware-boards.nix`, `_boards-lib.nix`,
  `publication.nix`.
- Spec: `binary-publication`.
- Consumers: cache-push tooling should skip blocked systems and scan before
  pushing.

## Revision: internal builders and the private cache (operator decision)

The operator allowed internal build machines and the controlled private cache for non-free artifacts wherever the vendor's terms permit. Operator authorization cannot grant a vendor license, so each manifest records what its license allows:

- **Internal build copies.** A new `build` form, implied by `file` and `private`, and the status `hardware.boards.publication.build`. A system that is not build-cleared is built where its R2 files were imported; each build machine may import them itself.
- **Private cache.** `private` now explicitly requires a cache that serves only the licensee's own systems. Enforcing that read boundary, through authentication or network isolation, belongs to the consumer configuration, not this repository.
- **Built packages** cannot permit forms their non-free inputs lack.

Per-vendor results (evidence in the manifests):
- NXP SLA v63 §2.2(a): internal reproduction for developing an Authorized System, no distribution to others. FRDM-i.MX95 NXP files permit `private`.
- eIQ Neutron SDK 3.1.2: its wheel ships NXP SLA v63 with "Standard use - Section 2.2 applies", so `private`. The converted model has no explicit clause on converter output; the operator approved treating it the same way (2026-10-13). This is the operator's interpretation, not a statement by NXP; it is recorded in the manifest evidence. Neither is publicly redistributable.
- TI Text File License: binary redistribution, so `file` (R1).
- TIDL tools 11_02_16_00 and the tidlruntime wheel: no embedded notice, but distributed through edgeai-tidl-tools 11_02_16_00 under the TI Text File License; the RegNet archive's model comes from edgeai-modelzoo (BSD-3-Clause) and facebookresearch/pycls (MIT). Operator-reviewed on 2026-10-13: R2, `private` only, no public form, until the files carry their notices.
- TexasInstruments-Sandbox patches and script: no license at the repository, directory or file level, so neither `build` nor `private`. The accelerator packages built from them stay blocked.
- Qualcomm LICENSE.qcom §1.1: reproduction and redistribution, so `private` (already set).

