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
        dragon-q8b-provider-contract = assert rejects "dragon-q8b: DT package" badDT;
        assert rejects "dragon-q8b: the kernel's provider" badKernel;
          pkgs.writeText "dragon-q8b-provider-contract" "Mismatched DT and unlabelled kernels are rejected.\n";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
              )
              (
                cd test-${toString sector}/second
                export out=$PWD/image.img
                ${img.buildCommand}
              )
              cmp test-${toString sector}/first/image.img test-${toString sector}/second/image.img
            '') [512 4096]}
            touch "$result"
          '';
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        dragon-q8b-production-rootfs-reproducibility =
          pkgs.runCommand "dragon-q8b-production-rootfs-reproducibility" {
            nativeBuildInputs = fixture.system.build.rootfsImage.nativeBuildInputs;
          } ''
            result=$out
            for attempt in first second; do
              mkdir "$attempt"
              sleep 2
              (
                cd "$attempt"
                export out=$PWD/root.img
                ${fixture.system.build.rootfsImage.buildCommand}
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
              mtype -i ${img}@@1048576 ::/loader/entries/nixos.conf | grep -F 'devicetree /nixos/dragon-q8b.dtb'
            '') [512 4096]}
            touch $out
          '';
      };
  };
}
