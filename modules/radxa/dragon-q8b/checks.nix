{
  config,
  lib,
  ...
}: let
  fixture = config.flake.nixosConfigurations.dragon-q8b-free.config;
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
    mockRoot =
      pkgs.runCommand "dragon-q8b-mock-ext4" {
        nativeBuildInputs = [pkgs.e2fsprogs pkgs.libfaketime];
      } ''
        truncate -s 32M $out
        faketime '1980-01-01 00:00:00' mkfs.ext4 -q -L NIXOS_Q8B \
          -U 81ad85de-22d0-4e73-8ebb-0512b0000004 \
          -E hash_seed=81ad85de-22d0-4e73-8ebb-0512b0000004 $out
      '';
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
      lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
