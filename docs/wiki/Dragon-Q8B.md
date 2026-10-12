# Radxa Dragon Q8B

SC8280XP ARM64 board support, tracked by [LAB-152](https://youtrack.k8s.bph/issue/LAB-152).
Maintainers have hardware; vendor Ubuntu observations do **not** verify these NixOS images.
See [hardware matrix](Dragon-Q8B-Hardware-Matrix), [firmware](Dragon-Q8B-Firmware),
[profile gaps](Dragon-Q8B-Free-vs-NonFree), and [boot/recovery](Dragon-Q8B-Boot-and-Recovery).

## Providers

The default is named vendor provider `radxa-7.0.11`, source revision
`a50eb5b71984bd82b49cd5d31b1e2eb5505c6512` from [radxa/kernel](https://github.com/radxa/kernel/tree/a50eb5b71984bd82b49cd5d31b1e2eb5505c6512).
The kernel and installed Q8B device tree share this source. Vendor selection emits a warning.
The mainline track is **blocked**, not experimentally bootable: the locked nixpkgs
mainline kernel is 6.18.54 and there is no compatible native Q8B DTS at the research
baseline. The operator explicitly rejected a factory-UEFI-DT exception. No mainline
provider module is exported and no vendor tree is labelled mainline.

Unblock only when a compatible native Q8B DTS or reviewed source backport is pinned,
compiled with its matching mainline kernel, and passes provider/DT-contract tests.
Then evaluate/build a separate mainline fixture and physically verify the core
serial/storage/PCIe functions before recommending it over the vendor provider.
The blocked mainline manifest tracks this missing support independently from
firmware licensing. It never blocks the vendor fixtures.

## Public fixtures

```console
nix build .#nixosConfigurations.dragon-q8b-free.config.system.build.image512
nix build .#nixosConfigurations.dragon-q8b-free.config.system.build.image4096
```

Images use GPT layout v1, a 512 MiB FAT32 ESP and ext4 root; they require a device
whose logical sectors match the chosen image. They expose local serial root autologin
only (115200 8N1), no SSH service, password or keys. Do not treat them as hardened deployments.
Board factory MACs are preserved; no per-device address is embedded in source.

The free profile installs no proprietary runtime blob. The full profile adds only
operator-imported ADSP and GPU SQE/GMU/ZAP, not unknown-license firmware; it cannot
be built until all four files have been imported after the operator reviews/accepts
their terms. The full profile never publicly publishes these operator-supplied blobs.
ADSP alone does not establish working audio: topology/service metadata remain gaps.
No default profile pulls all of linux-firmware or radxa-firmware into its closure.

## Hardware coverage

Core targets microSD, NVMe, UFS, serial and dual Toshiba PCIe Ethernet.
NixOS boot, device enumeration and network behavior remain implemented-unverified.
The Toshiba switch power-control node uses I2C21. The vendor GENI I2C driver reuses
an already initialized I2C engine, but requests the unestablished QUP firmware if
its protocol is invalid. Ethernet therefore also needs physical verification of
UEFI pre-initialization; a cold-start fallback cannot be claimed available without
establishing that exact QUP firmware's grant.
A UFS-attached vendor boot failed before readable firmware output; the failure is
not proof of a Linux driver problem or boot-order cause. Power off before fitting modules.
Wireless depends on the actual optional M.2 E-key card, not on the board name.
No integrated modem is assumed. Board connector bindings are documented only where
verified in the pinned DTS; this is not an assertion of generic HAT compatibility.
