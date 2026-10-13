## 1. Library

- [x] 1.1 `hardware.boards.publication.{private,blocking}`
- [x] 1.2 `lib.nonPrivateHashes` and `apps.private-cache-scan`
- [x] 1.3 Tests for the status and the hash list
- [x] 1.4 Internal build copies: the `build` redistribution form (implied by `file`/`private`), `lib.buildPermitted`, and `hardware.boards.publication.{build,buildBlocking}`
- [x] 1.5 Validation: built packages permit no form their non-free inputs lack; tests

## 2. Manifests

- [x] 2.1 FRDM-i.MX95: the NXP SLA v63 §2.2(a) grants internal reproduction, so files under it, and packages built only from them, permit `private`. The eIQ Neutron SDK wheel is under the same §2.2; its converted model permits `private` by the operator-approved interpretation in the manifest evidence.
- [x] 2.2 BeagleY-AI: TIDL tools, the tidlruntime wheel and the RegNet archive permit `private` only (R2, no public form; reviewed upstream grants, operator decision of 2026-10-13). The four TexasInstruments-Sandbox files have no license and permit neither `build` nor `private`, so the packages built from them stay blocked.
- [x] 2.3 Dragon Q8B: unchanged. LICENSE.qcom §1.1 already permits `private`.

## 3. Consumer (nixspace)

- [x] 3.1 push-cache and deploy-batch skip blocked systems and scan before pushing
- [x] 3.2 Host closure checks skip blocked systems
- [ ] 3.3 Establish the private cache's read boundary (consumer side; see proposal)

## 4. Close

- [ ] 4.1 Archive this change after merge
