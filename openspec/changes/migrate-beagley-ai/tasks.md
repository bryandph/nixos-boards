## 1. Library

- [x] 1.1 Built packages in release manifests: type, validation, unfree and cacheable lists, `mkBuilt`
- [x] 1.2 Built packages in the generated firmware and gap pages
- [x] 1.3 `mkImportTool` for R2 artifacts
- [x] 1.4 Library tests for built packages and the import tool
- [ ] 1.5 Per-board import apps and `hardwareChecks` wiring

## 2. BeagleY-AI

- [ ] 2.1 Release manifest `beagley-ai`: artifacts and built packages from the licensing review
- [ ] 2.2 Packages under `packages/beagleboard/beagley-ai/`, fetching non-free inputs only through artifacts
- [ ] 2.3 Features: core, image, header add-ons, display and camera profiles, USB gadget (free); multimedia, GPU, wireless, vision, accelerator runtime, camera stack, RegNet model, remoteproc IPC and full (non-free)
- [ ] 2.4 Resource claims through `hardware.boards.claims`
- [ ] 2.5 Registry, fixtures, CI checks and hardware checks
- [ ] 2.6 Wiki pages: board page, Boot and Recovery, and the BSP's topic pages
- [ ] 2.7 nixspace consumes nixos-boards for the beagleyai host

## 3. Close

- [ ] 3.1 Archive this change after merge
