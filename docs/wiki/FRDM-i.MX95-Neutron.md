# FRDM-i.MX95: Neutron NPU

The exported `frdm-imx95-neutron-npu` module is an evaluation role, not part of
the default FRDM core or image. It selects the evidence-approved Neutron kernel
provider and reviewed device tree, then adds the locally imported runtime,
operator-supplied converted model, least-privilege device access, and bounded
smoke interface. The accepted boot container is unchanged.

Treat `packages/nxp/frdm-imx95/imx95-lf-6.18.20-2.0.0.nix` as the authority for source
pointers, immutable identities, member paths, license authorities, and the
release-label reconciliation. Do not copy proprietary runtime, converter, or
converted-model bytes into this checkout or a public cache.

### Import the runtime and convert the smoke model

After reviewing the licenses referenced by the release mapping, check out the
pinned Neutron source locally and import only the selected members:

```console
nix run github:bryandph/nixos-boards#frdm-imx95-import-neutron-runtime -- \
  --accept-license /path/to/pinned-neutron-checkout
```

The command verifies the license, content register, SBOM, firmware, userspace
library, and required headers before adding the four runtime members
individually to the local Nix store under their release-pinned names and
SHA-256 identities. No runtime path needs to be passed to later evaluations.

Run model conversion on an `x86_64-linux` host. First import the eIQ
Neutron SDK wheel, which NXP publishes without a redistribution grant
(artifact `frdm-imx95.eiq-neutron-sdk-wheel`), then build the SDK and the
source model and convert:

```console
nix run github:bryandph/nixos-boards#frdm-imx95-import-artifacts -- --accept-license
converter_root="$(
  nix build --no-link --print-out-paths \
    github:bryandph/nixos-boards#legacyPackages.x86_64-linux.frdm-imx95.eiq-neutron-sdk
)"
model_root="$(
  nix build --no-link --print-out-paths \
    github:bryandph/nixos-boards#legacyPackages.x86_64-linux.frdm-imx95.imx95-neutron-model-source
)"
wheel=$(nix-store --print-fixed-path sha256 \
  adf64e34d116292038321dd14a7e38153a191f915850de6a14337304293878fe \
  eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl)
nix run github:bryandph/nixos-boards#frdm-imx95-convert-neutron-model -- \
  --accept-license \
  "$wheel" \
  "$converter_root/bin/neutron_converter" \
  "$model_root/share/models/mobilenet_v1_1.0_224_quant.tflite" \
  946a912f68b1d8d85ce33911287cdc3eedaf4cdbd1b102d7ba0c125c65a0e9ba
```

The derivation verifies the wheel and source-model identities, runs two
conversions with `--force-determinism`, rejects differing results, asserts the
converted identity pinned in the release mapping, and imports the verified
model under its pinned file name. Keep the resulting path local unless
affirmative redistribution authority is established.

Compose the module only in a dedicated evaluation configuration:

```nix
{
  imports = [
    inputs.nixos-boards.nixosModules.frdm-imx95-core
    inputs.nixos-boards.nixosModules.frdm-imx95-image
    inputs.nixos-boards.nixosModules.frdm-imx95-boot-container
    inputs.nixos-boards.nixosModules.frdm-imx95-neutron-npu
  ];

  users.users.<operator>.extraGroups = ["neutron"];
}
```

Aggregate systems and images inherit the unfree, non-redistributable,
local-build-preferred, substitute-disabled, and Hydra-disabled policy.

### Capture and accept the evaluation

After importing the four runtime members and converted model, build the
dedicated image without any licensed-input environment variables:

```console
nix build \
  github:bryandph/nixos-boards#legacyPackages.aarch64-linux.frdm-imx95.neutron-npu-sd-image
```

The configuration and image output are always present. If any licensed member
is absent, its `requireFile` boundary fails closed with the exact local import
procedure. The bytes remain operator-supplied and must not be published.

Identify the removable target independently with `findmnt`, `lsblk`, and the
MMC sysfs device type; never infer it from a previous `mmcblk` number. Write
only that unmounted SD medium. Do not write the eMMC user area, either eMMC
hardware boot partition, or persistent boot-selection state.

Capture both the A55 console (`ttyLP0`) and the M33/System Manager UART from
power-on. After a cold boot, collect at least:

```console
uname -a
nproc
cat /sys/devices/system/cpu/online
findmnt /
findmnt /boot
systemctl --failed
journalctl -b -k
ls -l /dev/neutron0
```

Verify six online A55 CPUs, the expected memory delta from the reusable Neutron
DMA pool, SCMI, OP-TEE, Ethernet/SSH, root and boot-medium identity, the
selected kernel/device tree, firmware loading, and no unexpected failed units.

Run the negative control and accelerator proof as the authorized non-root
operator:

```console
frdm-imx95-neutron-smoke --cpu-only
frdm-imx95-neutron-smoke
```

The CPU run must explicitly report non-acceptance. The Neutron run is accepted
only when its JSON report records the declared five-byte maximum quantized
output delta, the same top output, a nonzero delegated-node count, and movement
in the independent Neutron debugfs performance counters. The smoke wrapper uses
the dynamically linked compatibility benchmark from
`packages/nxp/frdm-imx95/imx95-neutron-benchmark.cc` so the executable and external delegate
share one TensorFlow Lite runtime. A successful benchmark exit or CPU fallback
is not accelerator evidence. Confirm separately that a user outside the
`neutron` group cannot open the device. Repeat the complete invariant and smoke
procedure after a second cold boot.

On failure, preserve the two UART logs, smoke JSON, `journalctl -b -k`,
`systemctl --failed`, mount identity, CPU/memory state, device permissions, and
hashes or store paths of selected inputs. Never attach proprietary bytes or
decoded content to an issue. Power off, remove the evaluation SD, boot the
untouched known-good installed/eMMC fleet system, and re-run its normal
invariants. Rollback requires no repair because the evaluation procedure does
not write eMMC or persistent boot-selection state.

### Updating the TensorFlow Lite dependency hash

The Bazel dependency archive in `packages/nxp/frdm-imx95/tensorflow-lite-imx95.nix` includes
toolchain-dependent content. A nixpkgs update can change its hash even when the
TensorFlow source and nixpkgs Bazel fetch implementation are unchanged.

Before repinning, compare `pkgs/build-support/build-bazel-package/default.nix`
at both nixpkgs revisions and obtain two independent dependency builds with the
new revision. Only accept a new hash when both samples agree. Align this
flake's nixpkgs lock with the consuming parent's revision in the same change;
then build `.#packages.aarch64-linux.tensorflow-lite-imx95.deps` and compare its
`drvPath` between standalone and parent evaluation. Finish by building the
runtime and affected host. Repeat this validation when updating nixpkgs.
