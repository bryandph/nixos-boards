# Add Dragon Q8B BSP

## Why

LAB-152 brings Radxa Dragon Q8B support into the already merged public conventions without depending on the unmerged board migration stack. LAB-151 owns artifact licensing and acquisition research.

## What Changes

- Add named, pinned Radxa vendor kernel and an explicitly blocked mainline track until compatible native DTS or a reviewed backport exists.
- Add free/full local-console fixtures and UEFI GPT images for 512/4096-byte logical sectors.
- Pin the observed board-owned UEFI version as a compatibility baseline, never fetch or flash it automatically.
- Adopt only firmware with established grants; acceptance-requiring files use optional operator import. Unknown grants remain blocked feature gaps.
- Generate hardware/firmware/gap documentation and add DT, image-layout and reproducibility checks.

## Impact

- New capability: dragon-q8b-board-support.
- No migration/retirement of existing BSPs or changes to PRs #1–#5.
- Hardware verification remains independent of software build checks; vendor OS observations are not NixOS verification.
- Work: https://youtrack.k8s.bph/issue/LAB-152 ; licensing: https://youtrack.k8s.bph/issue/LAB-151.
