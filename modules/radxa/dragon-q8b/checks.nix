{
  config,
  inputs,
  lib,
  ...
}: let
  fixtureSystem = config.flake.nixosConfigurations.dragon-q8b-free;
  fixture = fixtureSystem.config;
  overriddenESP =
    (fixtureSystem.extendModules {
      modules = [
        {
          fileSystems."/boot" = {
            device = "/dev/fixture-esp";
            options = ["noatime"];
          };
        }
      ];
    }).config.fileSystems."/boot";
  overriddenRoot =
    (fixtureSystem.extendModules {
      modules = [{fileSystems."/".device = "/dev/fixture-root";}];
    }).config;
  overriddenRootType =
    (fixtureSystem.extendModules {
      modules = [{fileSystems."/".fsType = "xfs";}];
    }).config;
  optedOutRoot =
    (fixtureSystem.extendModules {
      modules = [{fileSystems."/".autoResize = false;}];
    }).config;
  appendedInitrdModules =
    (fixtureSystem.extendModules {
      modules = [{boot.initrd.availableKernelModules = ["loop"];}];
    }).config;
  badDT = fixtureSystem.extendModules {
    modules = [({pkgs, ...}: {hardware.deviceTree.kernelPackage = lib.mkForce pkgs.linux;})];
  };
  badKernel = fixtureSystem.extendModules {
    modules = [({pkgs, ...}: {boot.kernelPackages = lib.mkForce pkgs.linuxPackages;})];
  };
  badSource = fixtureSystem.extendModules {
    modules = [({pkgs, ...}: {hardware.deviceTree.dtbSource = lib.mkForce (pkgs.writeTextDir "qcom/unrelated.dtb" "not a matching source");})];
  };
  layout = import ../../../packages/radxa/dragon-q8b/layout.nix;
  rejects = prefix: cfg: lib.any (a: !a.assertion && lib.hasPrefix prefix a.message) cfg.config.assertions;
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    mockSystem = pkgs.runCommand "dragon-q8b-mock-boot-inputs" {} ''
      mkdir -p $out/lib/systemd/boot/efi
      printf 'fixture kernel' > $out/kernel
      printf 'fixture initrd' > $out/initrd
      printf 'fixture dtb' > $out/dragon-q8b.dtb
      printf 'fixture efi' > $out/lib/systemd/boot/efi/systemd-bootaa64.efi
      mkdir -p $out/share/payload
      printf 'identical payload' > $out/share/payload/one
      cp --no-preserve=links $out/share/payload/one $out/share/payload/two
    '';
    mockRoot = pkgs.callPackage ../../../packages/radxa/dragon-q8b/rootfs.nix {
      nixpkgs = inputs.nixpkgs;
      toplevel = mockSystem;
    };
    mockConfig = {
      system.build.toplevel = mockSystem;
      systemd.package = mockSystem;
      hardware.deviceTree = {
        package = mockSystem;
        name = "dragon-q8b.dtb";
      };
      boot.kernelParams = ["console=ttyMSM0,115200n8"];
    };
    mockImage = sectorSize:
      pkgs.callPackage ../../../packages/radxa/dragon-q8b/image.nix {
        config = mockConfig;
        rootfs = mockRoot;
        inherit sectorSize;
      };
  in {
    # Operator-only proof needs TWO native build platforms; never force a
    # foreign derivation into single-architecture CI's standard checks.
    legacyPackages = lib.optionalAttrs (system == "aarch64-linux") {
      crossChecks.dragon-q8b-rootfs = let
        other = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ../../../packages/radxa/dragon-q8b/rootfs.nix {
          nixpkgs = inputs.nixpkgs;
          toplevel = fixture.system.build.toplevel;
        };
      in
        pkgs.runCommand "dragon-q8b-rootfs-cross-builder" {
          nativeBuildInputs = [pkgs.e2fsprogs.bin];
        } ''
          export LC_ALL=C
          cmp ${fixture.system.build.rootfsImage} ${other}
          e2fsck -fnv ${fixture.system.build.rootfsImage} > native-fsck.txt
          e2fsck -fnv ${other} > other-fsck.txt
          cat native-fsck.txt other-fsck.txt
          grep -Eq '^[[:space:]]*0[[:space:]]+(hard[[:space:]]+)?links[[:space:]]*$' native-fsck.txt
          grep -Eq '^[[:space:]]*0[[:space:]]+(hard[[:space:]]+)?links[[:space:]]*$' other-fsck.txt
          touch "$out"
        '';
    };
    checks =
      {
        dragon-q8b-bootstrap-lifecycle = assert !(lib.hasInfix "switch-to-configuration" fixture.systemd.services.register-nix-paths.script);
        assert (fixture.systemd.services.install-initial-bootloader.unitConfig.DefaultDependencies or true) != false;
        assert builtins.elem "register-nix-paths.service" fixture.systemd.services.install-initial-bootloader.requires;
        assert builtins.elem "register-nix-paths.service" fixture.systemd.services.install-initial-bootloader.after;
        assert fixture.systemd.services.install-initial-bootloader.unitConfig.ConditionPathExists == "/nix-path-registration";
        assert builtins.elem "umask=0077" fixture.fileSystems."/boot".options;
        assert overriddenESP.device == "/dev/fixture-esp";
        assert overriddenESP.fsType == "vfat";
        assert builtins.elem "umask=0077" overriddenESP.options;
        assert builtins.elem "noatime" overriddenESP.options;
          pkgs.runCommand "dragon-q8b-bootstrap-lifecycle" {} ''
            mkdir -p esp/loader/entries esp/EFI/nixos esp/dragon-q8b-bootstrap
            touch esp/loader/entries/dragon-q8b-bootstrap.conf
            touch esp/dragon-q8b-bootstrap/{linux,initrd,dragon-q8b.dtb}
            touch esp/loader/entries/nixos-generation-1.conf esp/EFI/nixos/managed-kernel marker
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/cleanup-bootstrap.sh} "$PWD/esp" "$PWD/marker"
            test ! -e marker
            test ! -e esp/loader/entries/dragon-q8b-bootstrap.conf
            test ! -e esp/dragon-q8b-bootstrap
            test -e esp/loader/entries/nixos-generation-1.conf
            test -e esp/EFI/nixos/managed-kernel
            mkdir -p esp/dragon-q8b-bootstrap
            touch esp/dragon-q8b-bootstrap/operator-file
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/cleanup-bootstrap.sh} "$PWD/esp" "$PWD/marker"
            test -e esp/dragon-q8b-bootstrap/operator-file
            export CALLS=$PWD/calls
            printf '#!${pkgs.runtimeShell}\nprintf "%%s\\n" "$@" > "$CALLS"\n' > fake-env
            chmod +x fake-env
            ln -s /initial-direct system
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/initialize-profile.sh} "$PWD/fake-env" "$PWD/system" /initial-current
            test -s calls
            rm calls system
            ln -s system-2-link system
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/initialize-profile.sh} "$PWD/fake-env" "$PWD/system" /older-booted-generation
            test ! -e calls
            touch "$out"
          '';
        dragon-q8b-root-growth-options = assert fixture.fileSystems."/".autoResize;
        assert fixture.fileSystems."/".device == "/dev/gpt-auto-root";
        assert fixture.fileSystems."/boot".device == "/dev/disk/by-designator/esp";
        assert builtins.elem "sysroot.mount" fixture.boot.initrd.systemd.services.dragon-q8b-boot-disk.requiredBy;
        assert builtins.elem "initrd-root-device.target" fixture.boot.initrd.systemd.services.dragon-q8b-boot-disk.after;
        assert !(overriddenRoot.boot.initrd.systemd.services ? dragon-q8b-boot-disk);
        assert builtins.elem "install-initial-bootloader.service" fixture.systemd.services.dragon-q8b-disk-ids.after;
        assert fixture.fileSystems."/".fsType == "ext4";
        assert overriddenRoot.fileSystems."/".device == "/dev/fixture-root";
        assert overriddenRoot.fileSystems."/".fsType == "ext4";
        assert overriddenRoot.fileSystems."/".autoResize;
        assert overriddenRootType.fileSystems."/".fsType == "xfs";
        assert overriddenRootType.fileSystems."/".autoResize;
        assert !optedOutRoot.fileSystems."/".autoResize;
        assert fixture.boot.growPartition && overriddenRoot.boot.growPartition && optedOutRoot.boot.growPartition;
        assert builtins.elem "x-systemd.growfs" fixture.fileSystems."/".options;
        assert builtins.elem "x-systemd.growfs" overriddenRoot.fileSystems."/".options;
        assert !(builtins.elem "x-systemd.growfs" optedOutRoot.fileSystems."/".options);
        assert fixture.boot.initrd.systemd.enable;
        assert builtins.elem "systemd-growfs-root.service" fixture.systemd.services.growpart.before;
          pkgs.writeText "dragon-q8b-root-growth-options" "Root growth defaults, overrides and unit ordering are evaluated.\n";
        dragon-q8b-initrd-tpm-options = assert builtins.elem "tpm_qcom_qsee" fixture.boot.initrd.availableKernelModules;
        assert builtins.elem "tpm_qcom_qsee" appendedInitrdModules.boot.initrd.availableKernelModules;
        assert builtins.elem "loop" appendedInitrdModules.boot.initrd.availableKernelModules;
        assert builtins.all (m: builtins.elem m fixture.boot.initrd.availableKernelModules) ["ufs_qcom" "phy_qcom_qmp_ufs" "nvme" "phy_qcom_qmp_pcie"];
        assert fixture.boot.initrd.systemd.tpm2.enable;
        assert fixture.boot.initrd.compressor == "zstd";
          pkgs.writeText "dragon-q8b-initrd-tpm-options" "Early TPM availability, module merging and TPM2 are evaluated.\n";
        dragon-q8b-provider-contract = assert rejects "dragon-q8b: DT package" badDT;
        assert rejects "dragon-q8b: the kernel's provider" badKernel;
        assert rejects "dragon-q8b: DT source" badSource;
          pkgs.writeText "dragon-q8b-provider-contract" "Mismatched DT and unlabelled kernels are rejected.\n";
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        # Inspect actual ARM assets only on native ARM CI. Option assertions
        # above remain checked on every platform without foreign build inputs.
        dragon-q8b-root-growth = pkgs.runCommand "dragon-q8b-root-growth" {} ''
          # The fixture uses systemd stage 1, not scripted resize2fs.
          grep -E '^/dev/gpt-auto-root / ext4 .*x-systemd.growfs' ${fixture.boot.initrd.systemd.managerEnvironment.SYSTEMD_SYSROOT_FSTAB}
          grep -E '^/dev/fixture-root / ext4 .*x-systemd.growfs' ${overriddenRoot.boot.initrd.systemd.managerEnvironment.SYSTEMD_SYSROOT_FSTAB}
          ! grep -F 'x-systemd.growfs' ${optedOutRoot.boot.initrd.systemd.managerEnvironment.SYSTEMD_SYSROOT_FSTAB}
          test -x ${fixture.systemd.package}/lib/systemd/systemd-growfs
          grep -F 'systemd-growfs' ${fixture.environment.etc."systemd/system".source}/systemd-growfs-root.service
          touch "$out"
        '';
        dragon-q8b-initrd-tpm =
          pkgs.runCommand "dragon-q8b-initrd-tpm" {
            nativeBuildInputs = [pkgs.zstd pkgs.cpio];
          } ''
            mkdir unpack
            zstd -d -c ${fixture.system.build.initialRamdisk}/initrd > initrd.cpio
            (cd unpack; cpio -id --quiet --no-absolute-filenames --no-preserve-owner < ../initrd.cpio)
            # Inspect archive members, not absolute symlinks into the builder's
            # modules store. The existing auxiliary driver has no module deps.
            find unpack -type f -name 'tpm_qcom_qsee.ko*' > modules
            find unpack -name 90-image-dissect.rules | grep -q .
            grep -rqF 'LoaderDevicePartUUID' unpack/nix/store/*-boot-disk-guard.sh
            test -s modules
            find unpack -type f -name modules.alias -exec grep -lF 'alias auxiliary:qcom_qseecom.tpm tpm_qcom_qsee' {} + > aliases
            test -s aliases
            find unpack -type f -name modules.dep -exec grep -lE '/tpm_qcom_qsee\.ko[^:]*:[[:space:]]*$' {} + > deps
            test -s deps
            touch "$out"
          '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        dragon-q8b-rootfs-store-topology = let
          copies = lib.filter (line: lib.hasPrefix "xargs -I % cp -a --no-preserve=links" line) (lib.splitString "\n" mockRoot.buildCommand);
          body = assert builtins.length copies == 1;
            lib.replaceStrings copies ["cp -a --no-preserve=links --reflink=auto source/$name -t ./rootImage/nix/store/"] mockRoot.buildCommand;
        in
          pkgs.runCommand "dragon-q8b-rootfs-store-topology" {
            nativeBuildInputs = mockRoot.nativeBuildInputs;
          } ''
            result=$out
            name=${builtins.baseNameOf "${mockSystem}"}
            for topology in linked plain; do
              mkdir -p "$topology/source"
              (
                cd "$topology"
                cp -a --no-preserve=links ${mockSystem} "source/$name"
                chmod u+w "source/$name/share/payload"
                if [ "$topology" = linked ]; then
                  rm "source/$name/share/payload/two"
                  ln "source/$name/share/payload/one" "source/$name/share/payload/two"
                  test "$(stat -c %h "source/$name/share/payload/one")" = 2
                else
                  test "$(stat -c %h "source/$name/share/payload/one")" = 1
                fi
                export out=$PWD/root.img
                ${body}
                test -z "$(find rootImage -type f -links +1 -print -quit)"
              )
            done
            cmp linked/root.img plain/root.img
            touch "$result"
          '';
        dragon-q8b-rootfs-reproducibility =
          pkgs.runCommand "dragon-q8b-rootfs-reproducibility" {
            nativeBuildInputs = mockRoot.nativeBuildInputs;
          } ''
            result=$out
            for attempt in first second; do
              mkdir "$attempt"
              sleep 2 # avoid an accidental pass from same-second staging timestamps
              (
                cd "$attempt"
                export out=$PWD/root.img
                ${mockRoot.buildCommand}
              )
            done
            cmp first/root.img second/root.img
            test -L first/rootImage/init
            test -L first/rootImage/nix/var/nix/profiles/system
            test -s first/rootImage/nix-path-registration
            touch "$result"
          '';
        # Written copies of one image must stop sharing GPT identifiers after first boot.
        dragon-q8b-disk-ids =
          pkgs.runCommand "dragon-q8b-disk-ids" {
            nativeBuildInputs = [pkgs.util-linux] ++ (mockImage 512).nativeBuildInputs;
          } ''
            result=$out
            export out=$PWD/image.img
            ${(mockImage 512).buildCommand}
            ids() { sfdisk --dump image.img | grep -E '^(label-id|image)'; }
            types() { sfdisk --part-type image.img 1; sfdisk --part-type image.img 2; }
            types > types.before
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/randomize-disk-ids.sh} image.img ${layout.diskId}
            ids > first
            ! grep -qiF -e ${layout.diskId} -e ${layout.espId} -e ${layout.rootId} first
            types | cmp - types.before
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/randomize-disk-ids.sh} image.img ${layout.diskId}
            ids | cmp - first
            bash -n ${../../../packages/radxa/dragon-q8b/boot-disk-guard.sh}
            touch "$result"
          '';
        # Exercise the exact production assembler cheaply before building kernels.
        # Re-run it twice from identical mock inputs: this tests assembler determinism,
        # not kernel/initrd/rootfs reproducibility (reported separately).
        dragon-q8b-image-layout =
          pkgs.runCommand "dragon-q8b-image-layout" {
            nativeBuildInputs = [pkgs.python3] ++ (mockImage 512).nativeBuildInputs;
            requiredSystemFeatures = ["big-parallel"];
          } ''
            result=$out
            ${lib.concatMapStrings (sector: let
              img = mockImage sector;
            in ''
              mkdir -p test-${toString sector}/first test-${toString sector}/second
              (
                cd test-${toString sector}/first
                export out=$PWD/image.img
                ${img.buildCommand}
                python ${../../../packages/radxa/dragon-q8b/verify-image.py} $out ${toString sector}
                python -O ${../../../packages/radxa/dragon-q8b/verify-image.py} $out ${toString sector}
                cp --reflink=auto "$out" corrupt.img
                printf '\\000' | dd of=corrupt.img bs=1 seek=510 conv=notrunc status=none
                if python -O ${../../../packages/radxa/dragon-q8b/verify-image.py} corrupt.img ${toString sector}; then
                  echo 'optimized validator accepted invalid MBR' >&2
                  exit 1
                fi
              )
              (
                cd test-${toString sector}/second
                export out=$PWD/image.img
                ${img.buildCommand}
              )
              cmp test-${toString sector}/first/image.img test-${toString sector}/second/image.img
              rm -rf test-${toString sector}
            '') [512 4096]}
            touch "$result"
          '';
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        dragon-q8b-production-rootfs-reproducibility =
          pkgs.runCommand "dragon-q8b-production-rootfs-reproducibility" {
            nativeBuildInputs = fixture.system.build.rootfsImage.nativeBuildInputs;
            requiredSystemFeatures = ["big-parallel"];
          } ''
            result=$out
            for attempt in first second; do
              mkdir "$attempt"
              sleep 2
              (
                cd "$attempt"
                export out=$PWD/root.img
                ${fixture.system.build.rootfsImage.buildCommand}
                # Only the completed image is needed for the comparison.
                # Make copied directories removable; do not follow store symlinks.
                find rootImage files -type d -exec chmod u+w {} +
                rm -rf rootImage files
              )
            done
            cmp first/root.img second/root.img
            touch "$result"
          '';
        # Production boot assets, not the mock kernel/loader used above.
        # This does not independently recompile the kernel or initrd closure.
        dragon-q8b-boot-reproducibility =
          pkgs.runCommand "dragon-q8b-boot-reproducibility" {
            nativeBuildInputs = fixture.system.build.image512.nativeBuildInputs;
            requiredSystemFeatures = ["big-parallel"];
          } ''
            result=$out
            ${lib.concatMapStrings (sector: let
              img = fixture.system.build."image${toString sector}";
            in ''
              mkdir -p production-${toString sector}/first production-${toString sector}/second
              (
                cd production-${toString sector}/first
                export out=$PWD/image.img
                ${img.buildCommand}
              )
              (
                cd production-${toString sector}/second
                export out=$PWD/image.img
                ${img.buildCommand}
              )
              cmp production-${toString sector}/first/image.img production-${toString sector}/second/image.img
              # Bound scratch usage to one sector pair, not four full images.
              rm -rf production-${toString sector}
            '') [512 4096]}
            touch "$result"
          '';
        dragon-q8b-dt-contract =
          pkgs.runCommand "dragon-q8b-dt-contract" {
            nativeBuildInputs = [pkgs.dtc];
          } ''
            dtb=${fixture.hardware.deviceTree.package}/${fixture.hardware.deviceTree.name}
            test "$(fdtget -t s "$dtb" / model)" = 'Radxa Dragon Q8B'
            test "$(fdtget -t s "$dtb" / compatible)" = 'radxa,dragon-q8b qcom,sc8280xp'
            ${lib.optionalString (fixture.hardware.deviceTree.kernelPackage != fixture.boot.kernelPackages.kernel) "exit 1"}
            touch $out
          '';
        dragon-q8b-image-structure =
          pkgs.runCommand "dragon-q8b-image-structure" {
            nativeBuildInputs = [pkgs.python3 pkgs.mtools];
          } ''
            ${lib.concatMapStrings (sector: let
              img = fixture.system.build."image${toString sector}";
            in ''
              python ${../../../packages/radxa/dragon-q8b/verify-image.py} ${img} ${toString sector}
              # ESP always starts at 1 MiB, independent of logical sector size.
              mdir -i ${img}@@1048576 ::/EFI/BOOT/BOOTAA64.EFI
              mtype -i ${img}@@1048576 ::/loader/entries/dragon-q8b-bootstrap.conf | grep -F 'devicetree /dragon-q8b-bootstrap/dragon-q8b.dtb'
            '') [512 4096]}
            touch $out
          '';
      };
  };
}
