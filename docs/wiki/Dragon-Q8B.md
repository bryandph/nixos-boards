# Radxa Dragon Q8B

SC8280XP ARM64 board support.
Maintainers have hardware. Bounded full-profile NVMe headless acceptance is recorded
in [boot/recovery](Dragon-Q8B-Boot-and-Recovery#headless-hardware-acceptance);
vendor Ubuntu observations alone do **not** verify NixOS images.
See [hardware matrix](Dragon-Q8B-Hardware-Matrix), [firmware](Dragon-Q8B-Firmware),
[profile gaps](Dragon-Q8B-Free-vs-NonFree), and [boot/recovery](Dragon-Q8B-Boot-and-Recovery).

## Providers

The default is named vendor provider `radxa-7.0.11`, source revision
`a50eb5b71984bd82b49cd5d31b1e2eb5505c6512` from [radxa/kernel](https://github.com/radxa/kernel/tree/a50eb5b71984bd82b49cd5d31b1e2eb5505c6512).
The kernel and installed Q8B device tree share this source. Vendor selection emits a warning.
The mainline track is **blocked**, not experimentally bootable. The generated
[firmware manifest](Dragon-Q8B-Firmware) derives its kernel version/revision from
the locked nixpkgs input; there was no compatible native Q8B DTS at the initial
research baseline (nixpkgs f45c6f04, Linux 6.18.54). The operator explicitly rejected a factory-UEFI-DT exception. No mainline
provider module is exported and no vendor tree is labelled mainline.

Unblock only when a compatible native Q8B DTS or reviewed source backport is pinned,
compiled with its matching mainline kernel, and passes provider/DT-contract tests.
Then evaluate/build a separate mainline fixture and physically verify the core
serial/storage/PCIe functions before recommending it over the vendor provider.
The core also guards `hardware.deviceTree.dtbSource` against a different base
source. Supported overlays use the matching kernel's DT base; direct overrides of
the internal `hardware.deviceTree.package` output are outside this contract.
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
their terms. The configured public targets use only the free profile; the
recorded terms grant no public redistribution of the operator-supplied blobs.
ADSP alone does not establish working audio: topology/service metadata remain gaps.
No default profile pulls all of linux-firmware or radxa-firmware into its closure.

## Hardware coverage

Core targets microSD, NVMe, UFS, serial and dual Toshiba PCIe Ethernet.
Full-profile NixOS headless boot on 512-byte-sector NVMe, UART output and one
PCIe Ethernet link were observed using this BSP with its Radxa vendor-kernel
provider, not merely the vendor OS. Full-profile headless boot from a
4096-byte-sector UFS module was also observed ([UFS boot](Dragon-Q8B-Boot-and-Recovery#ufs-boot)).
Free-fixture boot and NixOS microSD operation remain unverified. See the bounded
[hardware acceptance](Dragon-Q8B-Boot-and-Recovery#headless-hardware-acceptance).
The Toshiba switch power-control node uses I2C21. The vendor GENI I2C driver reuses
an already initialized I2C engine, but requests the unestablished QUP firmware if
its protocol is invalid. Ordinary warm-boot Ethernet success does not establish a
cold-start fallback or general UEFI pre-initialization guarantee without
establishing that exact QUP firmware's grant.
Power off before fitting modules.
Wireless depends on the actual optional M.2 E-key card, not on the board name.
No integrated modem is assumed. Board connector bindings are documented only where
verified in the pinned DTS; this is not an assertion of generic HAT compatibility.
