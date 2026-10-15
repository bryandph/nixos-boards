# FRDM-i.MX95: multimedia and the combined NXP kernel

## Mainline GPU and JPEG

The exported `frdm-imx95-multimedia` module is opt-in. It retains the board
core's upstream kernel, enables the open Mesa graphics stack, installs
hardware-evidencing GPU and JPEG probes, and defines standard `video` group
access for the V4L2 JPEG devices. It does not enable a display server,
desktop, camera, or NXP binary GPU userspace, and it is not imported by the
default board configuration.

```nix
{
  imports = [
    inputs.nixos-boards.nixosModules.frdm-imx95-core
    inputs.nixos-boards.nixosModules.frdm-imx95-image
    inputs.nixos-boards.nixosModules.frdm-imx95-boot-container
    inputs.nixos-boards.nixosModules.frdm-imx95-multimedia
  ];

  users.users.<operator>.extraGroups = ["video"];
}
```

On a physical board, run the probes as the non-root operator:

```console
frdm-imx95-gpu-smoke
frdm-imx95-jpeg-smoke
```

The GPU command creates a surfaceless EGL/GLES context, submits a deterministic
shader draw, validates pixel readback, rejects software renderers, and confirms
that Vulkan enumerates the Mali device through PanVK. The JPEG command
discovers encoder and decoder roles by V4L2 driver and formats, then performs a
generated BGR3 → JPEG → BGR3 hardware round trip. Both write JSON reports and
remove temporary files on every exit. The release mapping under
`packages/nxp/frdm-imx95/imx95-lf-6.18.20-2.0.0.nix` is the authority for expected drivers,
interfaces, and provenance.

## Wave6 VPU (NXP kernel)

Wave6 is not present in the accepted upstream kernel. The separate exported
`frdm-imx95-wave6-vpu` module selects the full release-pinned NXP kernel and
matching FRDM device tree explicitly. A reduced backport remains rejected by
the evidence gate until it builds, binds the physical VPU, and passes both
codec paths with every NXP-only dependency accounted for. Mainline GPU results
must not be attributed to this separate kernel target without rerunning them;
the composed all-features role below installs those probes for that purpose.

The Wave6 driver uses standard V4L2 mem2mem userspace, but its
`wave633c_codec_fw.bin` firmware member comes from NXP's licensed
`firmware-imx-8.32-1991416.bin` distribution. Review and accept that license,
then explicitly invoke the operator-only extraction/import app:

```console
nix run github:bryandph/nixos-boards#frdm-imx95-import-nxp-wave6-firmware -- \
  --accept-license /path/to/firmware-imx-8.32-1991416.bin
```

The app validates the pinned distribution before running NXP's extractor in
that explicitly accepted operator context, then validates and imports only
`wave633c_codec_fw.bin` (artifact `frdm-imx95.wave6-codec-member`): 524672 bytes,
SHA256 `279960869a8e6f736f4199217454993a2c8bdad4d934d823c6500da99f5fe647`.
The member pin was verified from the existing registered release-selected
output; it is not a claim of an independent vendor reacquisition. A derivation
uses `requireFile` for that member and installs pinned notices. No build runs
the vendor extractor or accepts an EULA, and the raw distribution is not
imported or retained in runtime closures. Missing input requires the operator
app; an agent must not accept or import it on the operator's behalf.

No standalone/public publication, public cache or image clearance is granted.
Only manifest-cleared controlled internal/private copies are eligible under
the recorded NXP terms and consumer gates. NXP SLA restrictions on reports and
licensed bytes remain applicable; this build boundary is not permission to
publish hardware reports or vendor content.

Compose the VPU role only in a dedicated removable-media evaluation:

```nix
{
  imports = [
    inputs.nixos-boards.nixosModules.frdm-imx95-core
    inputs.nixos-boards.nixosModules.frdm-imx95-image
    inputs.nixos-boards.nixosModules.frdm-imx95-boot-container
    inputs.nixos-boards.nixosModules.frdm-imx95-wave6-vpu
  ];

  users.users.<operator>.extraGroups = ["video"];
}
```

After confirming the kernel, device-tree, firmware, and `wave6` device
bindings, run:

```console
frdm-imx95-wave6-smoke
```

The command discovers Wave6 encoder and decoder roles and performs generated
H.264 and H.265 V4L2 round trips. It fails if no identified Wave6 hardware path
participates. Validate the feature image only from independently identified
removable media, without writing eMMC or persistent boot-selection state.
Rollback is powering off, removing the evaluation medium, and booting the
untouched known-good installed/eMMC fleet system.

## Combined NXP kernel

The exported `frdm-imx95-all-features` module is the combined kernel and
device-tree provider for a configuration that explicitly composes M7
remoteproc, the open Mesa GPU and V4L2 JPEG probes, Wave6 VPU, and Neutron NPU.
It selects the single `linux-imx95-all-features` package built from the pinned
NXP 6.18.20 source. That source already carries the FRDM M7 node, the Wave6 and
Neutron devices, and the Neutron reserved-memory overlay, so the mainline M7
overlay is intentionally suppressed in this composition. The provider does
not import the feature roles itself, preventing duplicate imports in parent
fleet compositions. The default core and each standalone evaluation role
remain separate and buildable.

```nix
{
  imports = [
    inputs.nixos-boards.nixosModules.frdm-imx95-core
    inputs.nixos-boards.nixosModules.frdm-imx95-image
    inputs.nixos-boards.nixosModules.frdm-imx95-boot-container
    inputs.nixos-boards.nixosModules.frdm-imx95-all-features
    inputs.nixos-boards.nixosModules.frdm-imx95-m7-remoteproc
    inputs.nixos-boards.nixosModules.frdm-imx95-multimedia
    inputs.nixos-boards.nixosModules.frdm-imx95-neutron-npu
    inputs.nixos-boards.nixosModules.frdm-imx95-wave6-vpu
  ];

  users.users.<operator>.extraGroups = [
    "neutron"
    "video"
  ];
}
```

The Wave6 firmware and Neutron runtime/model boundaries remain unfree,
non-redistributable, local-build preferred, substitute-disabled, and excluded
from Hydra. No public publication of the composed closure, SD image,
operator-extracted pinned member or converted model is cleared. Only the
manifest-recorded controlled internal/private forms are eligible under the
recorded terms and consumer gates. NXP's separate report restrictions remain
applicable; this does not authorize public hardware reports or vendor bytes. The image output is
`legacyPackages.aarch64-linux.frdm-imx95.all-features-sd-image`.
Validate this feature image only from removable media. Do not write eMMC or
persistent boot-selection state; rollback is booting the untouched known-good
installed/eMMC fleet system.
