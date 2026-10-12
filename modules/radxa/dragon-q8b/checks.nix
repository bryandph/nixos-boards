{
  config,
  inputs,
  lib,
  ...
}: let
  fixtureSystem = config.flake.nixosConfigurations.dragon-q8b-free;
  fixture = fixtureSystem.config;
  badDT = fixtureSystem.extendModules {
    modules = [({pkgs, ...}: {hardware.deviceTree.kernelPackage = lib.mkForce pkgs.linux;})];
  };
  badKernel = fixtureSystem.extendModules {
    modules = [({pkgs, ...}: {boot.kernelPackages = lib.mkForce pkgs.linuxPackages;})];
  };
  badSource = fixtureSystem.extendModules {
    modules = [({pkgs, ...}: {hardware.deviceTree.dtbSource = lib.mkForce (pkgs.writeTextDir "qcom/unrelated.dtb" "not a matching source");})];
  };
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
    checks =
      {
        dragon-q8b-bootstrap-lifecycle = assert !(lib.hasInfix "switch-to-configuration" fixture.systemd.services.register-nix-paths.script);
        assert (fixture.systemd.services.install-initial-bootloader.unitConfig.DefaultDependencies or true) != false;
        assert builtins.elem "register-nix-paths.service" fixture.systemd.services.install-initial-bootloader.requires;
        assert builtins.elem "register-nix-paths.service" fixture.systemd.services.install-initial-bootloader.after;
        assert fixture.systemd.services.install-initial-bootloader.unitConfig.ConditionPathExists == "/nix-path-registration";
          pkgs.runCommand "dragon-q8b-bootstrap-lifecycle" {} ''
            mkdir -p esp/loader/entries esp/EFI/nixos esp/dragon-q8b-bootstrap
            touch esp/loader/entries/dragon-q8b-bootstrap.conf
            touch esp/dragon-q8b-bootstrap/{linux,initrd,dragon-q8b.dtb}
            touch esp/loader/entries/nixos-generation-1.conf esp/EFI/nixos/managed-kernel
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/cleanup-bootstrap.sh} "$PWD/esp"
            test ! -e esp/loader/entries/dragon-q8b-bootstrap.conf
            test ! -e esp/dragon-q8b-bootstrap
            test -e esp/loader/entries/nixos-generation-1.conf
            test -e esp/EFI/nixos/managed-kernel
            mkdir -p esp/dragon-q8b-bootstrap
            touch esp/dragon-q8b-bootstrap/operator-file
            ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/cleanup-bootstrap.sh} "$PWD/esp"
            test -e esp/dragon-q8b-bootstrap/operator-file
            touch "$out"
          '';
        dragon-q8b-provider-contract = assert rejects "dragon-q8b: DT package" badDT;
        assert rejects "dragon-q8b: the kernel's provider" badKernel;
        assert rejects "dragon-q8b: DT source" badSource;
          pkgs.writeText "dragon-q8b-provider-contract" "Mismatched DT and unlabelled kernels are rejected.\n";
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
        # Rebuild the SAME ARM system closure using independent native tooling/store.
        # Kernel/initrd inputs remain fixed: this checks filesystem construction.
        dragon-q8b-rootfs-cross-builder = let
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
