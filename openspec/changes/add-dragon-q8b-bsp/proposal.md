# Add Dragon Q8B BSP

## Why

This final board stage adds reviewed Radxa Dragon Q8B support to the landed board/conventions stack. Artifact provenance and acquisition evidence remain in provider manifests; ordinary CI uses explicit output targets and normal authentication, not a separate publisher policy service.

## What Changes

- Add named, pinned Radxa vendor kernel and an explicitly blocked mainline track until compatible native DTS or a reviewed backport exists.
- Add free/full local-console fixtures and UEFI GPT images for 512/4096-byte logical sectors.
- Pin the observed board-owned UEFI version as a compatibility baseline, never fetch or flash it automatically.
- Adopt only firmware with established grants; acceptance-requiring files use optional operator import. Unknown grants remain blocked feature gaps.
- Generate hardware/firmware/gap documentation and add DT, image-layout and reproducibility checks.

## Impact

- New capability: dragon-q8b-board-support.
- No retirement, force-updates of prior source branches or changes to other boards/shared CI.
- Hardware verification remains independent of software build checks; vendor OS observations are not NixOS verification.
- Scope: BSP implementation and provider-manifest licensing evidence.
