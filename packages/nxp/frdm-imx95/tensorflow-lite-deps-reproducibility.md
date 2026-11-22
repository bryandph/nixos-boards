# TensorFlow Lite dependency archive reproducibility (LAB-241)

## Cause and evidence

The TensorFlow source remains `nxp-imx/tensorflow-imx` revision
`41cd35bea009fa11a7bceecfa1a9dcf3f9255628` (2.19.0).
Its gRPC dependency is still `b54a5b338637f92bfcf4b0bc05e0f57a5fd8fadd`;
`rules_go` is still v0.34.0. No dependency version is upgraded here.

The dependency initialization chain is:

1. `tensorflow/workspace2.bzl` fetches gRPC with its archive SHA-256 and
   applies `third_party/grpc/register_go_toolchain.patch`.
2. `tensorflow/workspace0.bzl` unconditionally calls `grpc_extra_deps()`.
3. The original patch calls `go_register_toolchains(version = "1.18.4")`.
4. `rules_go/go/private/sdk.bzl`, `_go_download_sdk_impl`, downloads
   `https://golang.org/dl/?mode=json&include=all` (fallback
   `https://golang.google.cn/dl/?mode=json&include=all`) **without a checksum**
   whenever the `sdks` attribute is empty, even when `version` is fixed.
5. It reads the selected Go archive checksum from that index and leaves the
   entire, continuously changing index in `external/go_sdk/versions.json`.
   `buildBazelPackage` archives it alongside the fixed SDK.

This is a time-dependent input, not evidence of changed Go SDK code or a
GitHub-regenerated source archive. On 2026-11-22 the index was 2,279,774 bytes,
SHA-256 `dff81fa9170d1a7c6a1f38b6cec38c0e3a9e67fd0354419c123ab7c8b8f3c3eb`,
and included go1.27.4 and go1.26.11. The SDK itself was still go1.18.4.

The unmodified expression freshly fetched under this repository's locked
nixpkgs `7c8764b7c7b09b34f632464276218ef9090eaa11` produces
`sha256-0Wy36/yHffDO7Gp/xopIN1MgdLMoT7JhtqOly9gGp20=`. An independent
`--rebuild` produced the same hash. This is **exactly** the supplied fleet
failure's result under nixspace's nixpkgs `3457b69` on aarch64 Graviton.
The fresh local evaluation/build instead used the configured aarch64 Linux
Rosetta builder. The observed drift therefore does not require that nixpkgs
upgrade or that builder change; today's archive is stable across those two
reported environments. This is not a claim of reproducibility across every
future nixpkgs/Bazel/Python revision or across different host architectures.
Bazel itself is separately pinned to 6.5.0 by `bazel-6.5.0.nix`.

### Limit on historical reconstruction

The 2026-11-07 tar with
`sha256-oVxR6CzmG4xbGMbIS6zoriUXCk44OrX43OKB4qKNUUU=` is unavailable.
We cannot truthfully give a byte-for-byte diff against that tar or assert
that *only* the index differed historically. The earlier pin
`sha256-qnuldxLFIW0hB03Pydo+HhjaIeTDbf6gBhxH0XqxACE=` is also not a
recoverable snapshot here. The pinned source rules reconstruct their
versions, URLs and checksum policy, not the historical bytes of an unhashed
HTTP response. The moving index is a demonstrated defect sufficient to
explain recurring drift; the exact old index response remains unknown.

`tensorflow-lite-deps-inventory.json` records all **90** repositories in the
observed tar, their defining rules/traces, and before/after source identities.
Here **before** explicitly means the current unmodified fetch plus the old
pinned rule definitions, not a fabricated reconstruction of the lost tar.
This distinction must survive review of the re-pin.

## Fix and vendored-set review

`grpc-pin-go-sdk.patch` replaces the version-only gRPC patch. It uses
`go_download_sdk` with explicit `sdks` entries, then registers the toolchains.
This is rules_go's supported mechanism for bypassing the release index:

| Platform | URL (unchanged selected version) | SHA-256 |
| --- | --- | --- |
| linux_arm64 | https://dl.google.com/go/go1.18.4.linux-arm64.tar.gz | `35014d92b50d97da41dade965df7ebeb9a715da600206aa59ce1b2d05527421f` |
| linux_amd64 | https://dl.google.com/go/go1.18.4.linux-amd64.tar.gz | `c9b099b68d93f5c5c8a8844a89f8db07eaa58270e3a1e01804f17f4cf8df02f5` |

Both checksums were independently checked against Go's published
[Go 1.18.4 download table](https://go.dev/dl/#go1.18.4), not merely trusted
because today's unhashed index reported them. The observed fetch selects
linux_arm64; linux_amd64 is covered for native x86 Linux builders as well,
but no x86 archive reproducibility claim is made by this aarch64 test.
There is no Darwin build for this aarch64-only package.

The three requested TFLite targets are C++ targets; the full build performed
no Go compilation. Go is fetched because gRPC initializes its toolchains
unconditionally. Keeping its already selected SDK with authenticated bytes
is less invasive than stubbing the repository or pruning transitive gRPC
initialization. The fetch also fails explicitly if `versions.json` returns.

Every member was compared by path, type, contents, mode, uid, gid, mtime,
symlink target and size. Comparing the current unmodified and fixed tar
(237,710 versus 237,709 entries), the **entire** difference is:

| File | Before | After |
| --- | --- | --- |
| `external/com_github_grpc_grpc/bazel/grpc_extra_deps.bzl` | 1,385 bytes; SHA-256 `a27bacf58bf0aa0d3ac26c232c4e76c74c7ba15da1132b5ce09f82938ec6b630` | 1,974 bytes; SHA-256 `81a888798ed6e0fb9910cdf1efc1b5bb78163fbaa6c7f05c8fe54dff8d9cdb74`; changes shown in `grpc-pin-go-sdk.patch` |
| `external/go_sdk/versions.json` | 2,279,774 bytes; SHA-256 above | absent; no index fetch |

All Go SDK files and all other repositories are byte-identical, including
metadata. No other version, URL, archive checksum or repository membership
changes. The gRPC archive itself retains SHA-256
`b956598d8cbe168b5ee717b5dafa56563eb5201a947856a6688bbeac9cac4e1f`.

### Other possible nondeterminism inspected

A separate fetch with
`--experimental_repository_resolved_file=/build/resolved.bzl` captured 108
resolved rules, including the local repositories removed by nixpkgs before
archiving. The inventory traces derive from that capture. The audit found:

- All 41 `http_archive`/`tf_http_archive` rules have explicit SHA-256 values.
  Their fetched URLs identify versions/commits, not moving branches/latest.
- The additional hermetic CPython 3.12.7 archive is checksum-pinned
  (`bba3c6be6153f715f2941da34f3a6a69c2d0035c9c5396bc5bb68c6d2bd1065a`).
  The bootstrap packaging 24.2 wheel is one of those 41 pinned HTTP rules.
  `pypi` generates lock-based repository definitions; no additional unlocked
  pip-installed package appears in this tar.
- CUDA/cuDNN are disabled. Their repositories and `cuda_redist_json` are
  generated empty stubs; their optional download paths are not exercised.
- Remote JDK, CMake and Ninja repositories present in the tar contain
  generated toolchain registrations, not their optional downloaded runtimes.
  LLVM's configured repository is generated from checksum-pinned `llvm-raw`.
- All 90 `@*.marker` files are normalized by nixpkgs to a newline. Local
  configuration and top-level symlink repositories are removed; retained
  symlink build-root references are normalized by nixpkgs. The tar sorts
  paths and fixes mtime to 1, uid/gid to 0.
- No generated Python bytecode differences were observed. The lone `.pyc`
  is rules_python's committed test fixture
  `gazelle/python/testdata/directive_python_test_file_pattern/test5_multiple_patterns/foo_unittest.pyc`,
  not a newly generated cache. No extra bytecode deletion or broad file
  stripping was needed, and no source fixture is removed.

The independent fixed fetch/rebuild matched in full, not just selected
files. No remaining nondeterminism was observed in this aarch64 environment.
Architecture-dependent SDK/configuration selection and future changes to
nixpkgs's fetch-phase tooling still require verification; this fix does not
pretend the FOD is universally environment-independent.

## Reproduction and validation

On `lab-241`, with new files staged, no `--impure` and no concurrency cap:

```sh
# The first diagnostic fetch used a fake hash; its mismatch reported YDF/….
# With that candidate supplied as an override, obtain/build the real FOD:
nix eval --raw .#legacyPackages.aarch64-linux.frdm-imx95.tensorflow-lite-imx95 \
  --apply 't: (t.override { fetchDepsSha256 = "sha256-YDF/2rU7tnWANCMPbobt7uoVvUP4H9PRwJK2Vqpcox8="; }).deps.drvPath'
nix build /nix/store/y3l4qplld5zxxa4n3ic96z9ml963yds6-tensorflow-lite-imx95-deps.tar.drv^* \
  --no-link --print-out-paths -L
# An independent check on the builder, not a substitution:
nix build --store ssh-ng://rosetta-builder --eval-store auto \
  /nix/store/y3l4qplld5zxxa4n3ic96z9ml963yds6-tensorflow-lite-imx95-deps.tar.drv^* \
  --rebuild --no-link --print-out-paths -L
# After adding the fail-closed preInstall guard, repeat on the final expression:
drv=$(nix eval --raw .#legacyPackages.aarch64-linux.frdm-imx95.tensorflow-lite-imx95.deps.drvPath)
nix build --store ssh-ng://rosetta-builder --eval-store auto "$drv^*" \
  --rebuild --no-link --print-out-paths -L
```

All fixed fetches/rebuilds produce
`sha256-YDF/2rU7tnWANCMPbobt7uoVvUP4H9PRwJK2Vqpcox8=`, output
`/nix/store/gjlnc19j8m7y1jbd8120zckc3ghhkxg9-tensorflow-lite-imx95-deps.tar`.
`external/go_sdk/versions.json` is absent, so changing the Go release index
cannot affect these bytes anymore. The checksummed Go archive is still the
same one; no nondeterministic files are silently discarded.

The full aarch64 TFLite build of the final expression completed all 3,105
Bazel actions (the two shared libraries, benchmark_model, and the installed
dynamic smoke benchmark), output
`/nix/store/v3q1kpl5y3yap18wkg5wbk8nhvkhff12-tensorflow-lite-imx95`.
This includes the fail-closed fetch guard and whitespace-clean patch file.
Its aarch64 delegate derivation evaluates to
`/nix/store/2ra1lh8ldh2yhxm7s78zw6p57ywgdmc3-frdm-imx95-tflite-neutron-delegate-2.19.0.drv`.
The existing `frdm-imx95-neutron-tflite-deps-override` check builds and verifies
that a changed deps pin changes the delegate and that the delegate receives
the corresponding TFLite derivation. `frdm-imx95-neutron-provenance`,
`release-manifests` and `wiki-links` also build on aarch64-linux.

```sh
nix run .#fmt
nix flake check --no-build
nix eval --raw .#nixosConfigurations.frdm-imx95-full.config.system.build.delegate.drvPath
nix build .#legacyPackages.aarch64-linux.frdm-imx95.tensorflow-lite-imx95 \
  .#checks.aarch64-linux.frdm-imx95-neutron-tflite-deps-override \
  .#checks.aarch64-linux.frdm-imx95-neutron-provenance \
  .#checks.aarch64-linux.release-manifests .#checks.aarch64-linux.wiki-links \
  --no-link --print-out-paths -L
```

The formatter is clean. Flake evaluation passes on the default Mac system;
it explicitly omits incompatible Linux systems, hence the additional
explicit aarch64 builds above. Free space on the Mac `/nix` was 436 GB before
and 410 GB after this investigation, above the 100 GB floor.
No firmware or runtime blobs were fetched, imported or re-licensed for this
investigation. The licensed delegate itself was evaluated, not built;
hardware execution is not claimed. Merge remains subject to review of this
analysis and the historical-evidence limitation, not acceptance of a hash alone.
