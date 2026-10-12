{
  config,
  inputs,
  lib,
  ...
}: let
  frdm = import ./_scope.nix {inherit config;};
  boardsLib = config.boards.lib;
  manifest = config.boards.manifests.frdm-imx95;
  release = import ../../../packages/nxp/frdm-imx95/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  m7Vring0 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 0;
  m7Vring1 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 1;
  m7Vring2 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 2;
  m7Vring3 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 3;
  # The board's generated unfree list.
  allowedUnfreeNames = boardsLib.unfreePackages [manifest];

  boardModule = imageBaseName: {
    networking = {
      hostName = "frdm-imx95";
      useDHCP = lib.mkDefault true;
    };

    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) allowedUnfreeNames;

    services.openssh.enable = false;

    image.baseName = imageBaseName;
    system.stateVersion = "26.05";
  };

  mkBoard = {
    imageBaseName,
    modules ? [],
  }:
    inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules =
        [
          config.flake.modules.nixos.frdm-imx95-core
          config.flake.modules.nixos.frdm-imx95-image
          config.flake.modules.nixos.frdm-imx95-boot-container
          (boardModule imageBaseName)
        ]
        ++ modules;
    };
  # Check configurations (not exported): the old BSP's board variants.
  boards =
    {
      frdm-imx95 = mkBoard {
        imageBaseName = "nixos-frdm-imx95";
      };

      frdm-imx95-source-built = mkBoard {
        imageBaseName = "nixos-frdm-imx95-source-built";
      };

      frdm-imx95-m7-remoteproc = mkBoard {
        imageBaseName = "nixos-frdm-imx95-m7-remoteproc";
        modules = [
          config.flake.modules.nixos.frdm-imx95-m7-remoteproc
        ];
      };

      frdm-imx95-multimedia = mkBoard {
        imageBaseName = "nixos-frdm-imx95-multimedia";
        modules = [
          config.flake.modules.nixos.frdm-imx95-multimedia
        ];
      };

      frdm-imx95-compatibility = mkBoard {
        imageBaseName = "nixos-frdm-imx95-compatibility";
        modules = [
          ({pkgs, ...}: {
            hardware.boards.imx95.bootContainer = (frdm pkgs).completeBootContainer;
          })
        ];
      };
    }
    // {
      frdm-imx95-all-features = mkBoard {
        imageBaseName = "nixos-frdm-imx95-all-features";
        modules = [
          config.flake.modules.nixos.frdm-imx95-all-features
          config.flake.modules.nixos.frdm-imx95-audio
          config.flake.modules.nixos.frdm-imx95-m7-remoteproc
          config.flake.modules.nixos.frdm-imx95-multimedia
          config.flake.modules.nixos.frdm-imx95-neutron-npu
          config.flake.modules.nixos.frdm-imx95-nvme
          config.flake.modules.nixos.frdm-imx95-wave6-vpu
        ];
      };

      frdm-imx95-neutron-npu = mkBoard {
        imageBaseName = "nixos-frdm-imx95-neutron-npu";
        modules = [
          config.flake.modules.nixos.frdm-imx95-neutron-npu
        ];
      };
    };
in {
  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") (
      let
        scope = frdm (import inputs.nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfreeNames;
        });
        board = boards.frdm-imx95;
        allFeaturesBoard = boards.frdm-imx95-all-features;
        allFeaturesRuntime = allFeaturesBoard.config.system.build.runtime;
        allFeaturesSdImage = allFeaturesBoard.config.system.build.frdmImx95SdImage.overrideAttrs (old: {
          allowSubstitutes = false;
          preferLocalBuild = true;
          passthru =
            (old.passthru or {})
            // {publicationPolicy = allFeaturesRuntime.publicationPolicy;};
          meta =
            (old.meta or {})
            // {
              hydraPlatforms = [];
            };
        });
        m7Board = boards.frdm-imx95-m7-remoteproc;
        multimediaBoard = boards.frdm-imx95-multimedia;
        neutronBoard = boards.frdm-imx95-neutron-npu;
        neutronRuntime = neutronBoard.config.system.build.runtime;
        neutronSdImage = neutronBoard.config.system.build.frdmImx95SdImage.overrideAttrs (old: {
          allowSubstitutes = false;
          preferLocalBuild = true;
          passthru =
            (old.passthru or {})
            // {publicationPolicy = neutronRuntime.publicationPolicy;};
          meta =
            (old.meta or {})
            // {
              hydraPlatforms = [];
            };
        });
        sourceBoard = board;
        compatibilityBoard = boards.frdm-imx95-compatibility;
        compatibilityBootContainer = compatibilityBoard.config.hardware.boards.imx95.bootContainer;
        compatibilityBootContainerName = compatibilityBootContainer.fileName;
        sdImage = board.config.system.build.frdmImx95SdImage;
        sourceSdImage = sourceBoard.config.system.build.frdmImx95SdImage;
        compatibilitySdImage = compatibilityBoard.config.system.build.frdmImx95SdImage;
        configuredSourceBootContainer = sourceBoard.config.hardware.boards.imx95.bootContainer;
        sourceManifestNames =
          map
          (component: component.name)
          configuredSourceBootContainer.componentManifest;
        expectedSourceManifestNames = [
          "imx-atf-imx95"
          "imx-mkimage-imx95"
          "imx-oei-imx95-frdm"
          "imx-optee-os-imx95"
          "imx-system-manager-imx95"
          "lpddr4x_dmem_qb_v202409.bin"
          "lpddr4x_dmem_v202409.bin"
          "lpddr4x_imem_qb_v202409.bin"
          "lpddr4x_imem_v202409.bin"
          "mx95b0-ahab-container.img"
          "uboot-imx95-frdm"
        ];
        sourceProvenanceNames =
          map
          (provenance: provenance.shortName)
          configuredSourceBootContainer.meta.sourceProvenance;
        uboot = scope.uboot;
        armTrustedFirmware = scope.armTrustedFirmware;
        optee = scope.optee;
        systemManager = scope.systemManager;
        oei = scope.oei;
        imxMkimage = scope.imxMkimage;
        licensedFirmware = scope.licensedFirmware;
        m7CompatibilityFirmware = licensedFirmware.m7PowerModeDemo;
        inherit (scope) sourceBootContainer m7SourceBootContainer;
        sourceBootContainerReproA = sourceBootContainer.override {buildInstance = "repro-a";};
        sourceBootContainerReproB = sourceBootContainer.override {buildInstance = "repro-b";};
        missingMetadataProvider = pkgs.runCommand "frdm-imx95-missing-metadata-provider" {} ''
          mkdir "$out"
        '';
        missingMetadataBoard = mkBoard {
          imageBaseName = "nixos-frdm-imx95-invalid-metadata";
          modules = [
            {hardware.boards.imx95.bootContainer = missingMetadataProvider;}
          ];
        };
        unsafeProvider =
          sourceBootContainer
          // {
            expectedSize = 8 * 1024 * 1024;
          };
        unsafeProviderBoard = mkBoard {
          imageBaseName = "nixos-frdm-imx95-unsafe-provider";
          modules = [
            {hardware.boards.imx95.bootContainer = unsafeProvider;}
          ];
        };
        failedAssertions = boardConfig:
          builtins.filter (assertion: !assertion.assertion) boardConfig.config.assertions;
        compatibilityBootContainerOffsetBytes =
          compatibilityBoard.config.hardware.boards.imx95.bootContainerOffsetKiB * 1024;
        sourceBootContainerOffsetBytes =
          sourceBoard.config.hardware.boards.imx95.bootContainerOffsetKiB * 1024;
        ubootEnvironmentOffsetBytes =
          board.config.hardware.boards.imx95.ubootEnvironmentOffsetKiB * 1024;
        compatibilityUbootEnvironmentOffsetBytes =
          compatibilityBoard.config.hardware.boards.imx95.ubootEnvironmentOffsetKiB * 1024;
        firmwareOffsetBytes = board.config.sdImage.firmwarePartitionOffset * 1024 * 1024;
        rootOffsetBytes =
          (board.config.sdImage.firmwarePartitionOffset + board.config.sdImage.firmwareSize)
          * 1024
          * 1024;
      in {
        # Images and boot-chain packages for operators and checks.
        boardPackages.frdm-imx95 = {
          inherit
            armTrustedFirmware
            imxMkimage
            oei
            optee
            sdImage
            systemManager
            uboot
            ;
          m7-remoteproc-sd-image = m7Board.config.system.build.frdmImx95SdImage;
          multimedia-sd-image = multimediaBoard.config.system.build.frdmImx95SdImage;
          m7-source-boot-container = m7SourceBootContainer;
          source-boot-container = sourceBootContainer;
          source-built-sd-image = sourceSdImage;
          compatibility-sd-image = compatibilitySdImage;
          complete-boot-container = compatibilityBootContainer;
          ele-firmware = licensedFirmware.ele;
          lpddr4x-dmem = licensedFirmware.lpddr4xDmem;
          lpddr4x-dmem-qb = licensedFirmware.lpddr4xDmemQuickBoot;
          lpddr4x-imem = licensedFirmware.lpddr4xImem;
          lpddr4x-imem-qb = licensedFirmware.lpddr4xImemQuickBoot;
          m7-power-mode-demo = m7CompatibilityFirmware;
          all-features-sd-image = allFeaturesSdImage;
          neutron-npu-sd-image = neutronSdImage;
        };

        frdmChecks =
          {
            neutron-default-closure-independence =
              pkgs.runCommand "frdm-imx95-neutron-default-closure-independence" {
                exportReferencesGraph = [
                  "default-system-closure"
                  board.config.system.build.toplevel
                  "default-image-closure"
                  sdImage
                ];
              } ''
                for graph in default-system-closure default-image-closure; do
                  if grep -qi neutron "$graph"; then
                    echo "$graph unexpectedly references Neutron content" >&2
                    exit 1
                  fi
                done
                test ${
                  if
                    lib.hasAttrByPath
                    ["hardware" "nxp" "imx95" "neutron"]
                    board.options
                  then "0"
                  else "1"
                } = 1
                touch "$out"
              '';

            m7-compatibility-provider-evaluation =
              pkgs.runCommand "frdm-imx95-m7-compatibility-provider-evaluation" {
                allowSubstitutes = false;
                preferLocalBuild = true;
                meta = {
                  hydraPlatforms = [];
                };
              } ''
                test ${lib.escapeShellArg m7CompatibilityFirmware.fileName} = \
                  imx95-15x15-frdm_m7_TCM_power_mode_switch.bin
                test ${lib.escapeShellArg m7CompatibilityFirmware.firmwareFormat} = \
                  raw-binary
                test ${toString m7CompatibilityFirmware.expectedSize} -eq 35916
                test ${lib.escapeShellArg m7CompatibilityFirmware.expectedSha256} = \
                  15141ba5c66504131b45c5daf29f2cf1a75273cff8f18f0cc205aa3a4d57cdb9
                test ${
                  if m7CompatibilityFirmware.remoteprocLoadable
                  then "0"
                  else "1"
                } = 1
                test ${
                  if m7CompatibilityFirmware.allowSubstitutes
                  then "0"
                  else "1"
                } = 1
                test ${
                  if m7CompatibilityFirmware.preferLocalBuild
                  then "1"
                  else "0"
                } = 1
                test ${
                  if m7CompatibilityFirmware.meta.license.redistributable
                  then "0"
                  else "1"
                } = 1
                test ${toString (builtins.length m7CompatibilityFirmware.meta.hydraPlatforms)} -eq 0
                touch "$out"
              '';

            module-evaluation = pkgs.runCommand "frdm-imx95-module-evaluation" {} ''
              test ${lib.escapeShellArg configuredSourceBootContainer.providerKind} = \
                source-assembled
              test ${lib.escapeShellArg configuredSourceBootContainer.release} = \
                6.18.20-2.0.0
              test ${lib.escapeShellArg configuredSourceBootContainer.fileName} = \
                imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55
              test ${toString configuredSourceBootContainer.expectedSize} -eq \
                ${toString board.config.hardware.boards.imx95.bootContainerSizeBytes}
              test ${toString configuredSourceBootContainer.bootContainerOffsetKiB} -eq \
                ${toString board.config.hardware.boards.imx95.bootContainerOffsetKiB}
              test ${lib.escapeShellArg board.config.hardware.deviceTree.name} = \
                freescale/imx95-15x15-frdm.dtb
              test ${lib.escapeShellArg board.config.fileSystems."/".device} = \
                /dev/disk/by-label/NIXOS_SD
              test ${
                if builtins.hasAttr "/boot" board.config.fileSystems
                then "1"
                else "0"
              } = 0
              bootGenerator=${
                lib.escapeShellArg board.config.systemd.generators.frdm-imx95-root-boot
              }
              test -x "$bootGenerator"
              grep -q 'rootMajorMinor=' "$bootGenerator"
              grep -q 'bootPartition=' "$bootGenerator"
              test ${
                if builtins.hasAttr "/boot/firmware" board.config.fileSystems
                then "1"
                else "0"
              } = 0
              test ${
                if lib.hasInfix ''-N "$partNum"'' board.config.systemd.services.expand-root-partition.script
                then "1"
                else "0"
              } = 1
              test ${
                if allFeaturesBoard.config.boot.initrd.kernelModules == []
                then "1"
                else "0"
              } = 1
              test ${
                if lib.hasInfix "/sys/dev/block/" board.config.systemd.services.expand-root-partition.script
                then "1"
                else "0"
              } = 1
              test ${
                if lib.hasInfix "-nr -o MAJ:MIN" board.config.systemd.services.expand-root-partition.script
                then "1"
                else "0"
              } = 1
              test ${
                if sdImage.allowSubstitutes
                then "1"
                else "0"
              } = 0
              test ${
                if (sdImage.meta.license.redistributable or false)
                then "1"
                else "0"
              } = 0
              touch "$out"
            '';

            m7-boot-container-evaluation = pkgs.runCommand "frdm-imx95-m7-boot-container-evaluation" {} ''
              test ${lib.escapeShellArg m7SourceBootContainer.providerKind} = \
                source-assembled
              test ${lib.escapeShellArg m7SourceBootContainer.systemManagerConfig} = \
                mx95evk
              test ${lib.escapeShellArg m7SourceBootContainer.systemManagerPolicy} = \
                m7-remoteproc-lmm
              test ${lib.escapeShellArg m7SourceBootContainer.fileName} = \
                imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55-m7-remoteproc
              test ${
                if m7SourceBootContainer.containsM7Application
                then "0"
                else "1"
              } = 1
              test ${lib.escapeShellArg m7Board.config.hardware.boards.imx95.bootContainer.systemManagerConfig} = \
                mx95evk
              test ${lib.escapeShellArg m7Board.config.hardware.boards.imx95.bootContainer.systemManagerPolicy} = \
                m7-remoteproc-lmm
              test ${lib.escapeShellArg board.config.hardware.boards.imx95.bootContainer.systemManagerConfig} = \
                mx95evk
              test ${lib.escapeShellArg board.config.hardware.boards.imx95.bootContainer.systemManagerPolicy} = \
                default
              touch "$out"
            '';

            compatibility-provider-evaluation = pkgs.runCommand "frdm-imx95-compatibility-provider-evaluation" {} ''
              test ${lib.escapeShellArg compatibilityBootContainer.providerKind} = \
                nxp-complete-container
              test ${lib.escapeShellArg compatibilityBootContainer.release} = \
                6.18.20-2.0.0
              test ${lib.escapeShellArg compatibilityBootContainer.fileName} = \
                imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all
              test ${toString compatibilityBootContainer.expectedSize} -eq \
                ${toString compatibilityBoard.config.hardware.boards.imx95.bootContainerSizeBytes}
              test ${
                if compatibilitySdImage.allowSubstitutes
                then "1"
                else "0"
              } = 0
              test ${
                if (compatibilitySdImage.meta.license.redistributable or false)
                then "1"
                else "0"
              } = 0
              touch "$out"
            '';

            source-provider-evaluation = pkgs.runCommand "frdm-imx95-source-provider-evaluation" {} ''
              test ${lib.escapeShellArg configuredSourceBootContainer.providerKind} = \
                source-assembled
              test ${lib.escapeShellArg configuredSourceBootContainer.release} = \
                6.18.20-2.0.0
              test ${lib.escapeShellArg configuredSourceBootContainer.fileName} = \
                imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55
              test ${toString configuredSourceBootContainer.expectedSize} -eq \
                ${toString sourceBoard.config.hardware.boards.imx95.bootContainerSizeBytes}
              test ${toString (builtins.length sourceManifestNames)} -eq \
                ${toString (builtins.length expectedSourceManifestNames)}
              test ${
                if
                  lib.all
                  (name: builtins.elem name sourceManifestNames)
                  expectedSourceManifestNames
                then "1"
                else "0"
              } = 1
              test ${
                if builtins.elem "fromSource" sourceProvenanceNames
                then "1"
                else "0"
              } = 1
              test ${
                if builtins.elem "binaryFirmware" sourceProvenanceNames
                then "1"
                else "0"
              } = 1
              test ${
                if configuredSourceBootContainer.allowSubstitutes
                then "1"
                else "0"
              } = 0
              test ${
                if configuredSourceBootContainer.meta.license.redistributable
                then "1"
                else "0"
              } = 0
              test ${toString (builtins.length configuredSourceBootContainer.meta.hydraPlatforms)} -eq 0
              test ${
                if configuredSourceBootContainer.containsM7Application
                then "1"
                else "0"
              } = 0
              test ${
                if sourceSdImage.allowSubstitutes
                then "1"
                else "0"
              } = 0
              test ${
                if (sourceSdImage.meta.license.redistributable or false)
                then "1"
                else "0"
              } = 0
              touch "$out"
            '';

            firmware-fail-closed =
              pkgs.runCommand "frdm-imx95-firmware-fail-closed" {
                nativeBuildInputs = [pkgs.coreutils];
              } ''
                printf valid-firmware > firmware.bin
                validHash=$(sha256sum firmware.bin | cut -d' ' -f1)
                validSize=$(stat -c %s firmware.bin)

                ${lib.getExe pkgs.bash} ${../../../packages/nxp/frdm-imx95/scripts/check-nxp-firmware-file} \
                  firmware.bin "$validHash" "$validSize"

                if ${lib.getExe pkgs.bash} ${../../../packages/nxp/frdm-imx95/scripts/check-nxp-firmware-file} \
                  missing.bin "$validHash" "$validSize"; then
                  echo "missing firmware unexpectedly passed validation" >&2
                  exit 1
                fi
                if ${lib.getExe pkgs.bash} ${../../../packages/nxp/frdm-imx95/scripts/check-nxp-firmware-file} \
                  firmware.bin \
                  0000000000000000000000000000000000000000000000000000000000000000 \
                  "$validSize"; then
                  echo "mismatched firmware identity unexpectedly passed validation" >&2
                  exit 1
                fi
                if ${lib.getExe pkgs.bash} ${../../../packages/nxp/frdm-imx95/scripts/check-nxp-firmware-file} \
                  firmware.bin "$validHash" "$(( validSize + 1 ))"; then
                  echo "mismatched firmware size unexpectedly passed validation" >&2
                  exit 1
                fi

                touch "$out"
              '';

            provider-fail-closed =
              pkgs.runCommand "frdm-imx95-provider-fail-closed" {
                nativeBuildInputs = [pkgs.coreutils];
              } ''
                printf valid-container > container.bin
                validHash=$(sha256sum container.bin | cut -d' ' -f1)
                validSize=$(stat -c %s container.bin)

                validate=${../../../packages/nxp/frdm-imx95/scripts/check-imx95-boot-container}
                ${lib.getExe pkgs.bash} "$validate" \
                  container.bin "$validHash" "$validSize" 32768 8388608 7340032

                if ${lib.getExe pkgs.bash} "$validate" \
                  missing.bin "$validHash" "$validSize" 32768 8388608 7340032; then
                  echo "missing provider output unexpectedly passed validation" >&2
                  exit 1
                fi
                if ${lib.getExe pkgs.bash} "$validate" \
                  container.bin \
                  0000000000000000000000000000000000000000000000000000000000000000 \
                  "$validSize" 32768 8388608 7340032; then
                  echo "provider identity mismatch unexpectedly passed validation" >&2
                  exit 1
                fi
                if ${lib.getExe pkgs.bash} "$validate" \
                  container.bin "$validHash" "$(( validSize + 1 ))" \
                  32768 8388608 7340032; then
                  echo "provider size mismatch unexpectedly passed validation" >&2
                  exit 1
                fi
                if ${lib.getExe pkgs.bash} "$validate" \
                  container.bin "$validHash" "$validSize" \
                  7340032 8388608 7340032; then
                  echo "unsafe provider unexpectedly passed validation" >&2
                  exit 1
                fi

                test ${
                  if
                    lib.any
                    (failure: lib.hasInfix "metadata contract" failure.message)
                    (failedAssertions missingMetadataBoard)
                  then "1"
                  else "0"
                } = 1
                test ${
                  if
                    lib.any
                    (failure: lib.hasInfix "overlap" failure.message)
                    (failedAssertions unsafeProviderBoard)
                  then "1"
                  else "0"
                } = 1

                touch "$out"
              '';

            source-container-structure =
              pkgs.runCommand "frdm-imx95-source-container-structure" {
                allowSubstitutes = false;
                preferLocalBuild = true;
                meta = {
                  hydraPlatforms = [];
                };
              } ''
                ${imxMkimage}/bin/mkimage_imx8 \
                  -soc IMX9 \
                  -parse \
                  "${configuredSourceBootContainer}/${configuredSourceBootContainer.fileName}" \
                  > inventory.txt
                ${imxMkimage}/bin/mkimage_imx8 \
                  -soc IMX9 \
                  -extract \
                  "${configuredSourceBootContainer}/${configuredSourceBootContainer.fileName}" \
                  > /dev/null

                install -m0644 "${optee}/${optee.artifacts.teeRaw}" expected-tee.bin
                truncate \
                  -s "$(stat -c %s extracted_imgs/app_container1_img3.bin)" \
                  expected-tee.bin
                cmp expected-tee.bin extracted_imgs/app_container1_img3.bin

                grep -q 'IMAGE 1 (ELE FW)' inventory.txt
                grep -q 'IMAGE 2 (DDR Init)' inventory.txt
                grep -q 'IMAGE 3 (M33)' inventory.txt
                grep -q 'CORE_CM33' inventory.txt
                grep -q 'IMAGE 4 (Bootloader)' inventory.txt
                grep -q 'CORE_CA55' inventory.txt
                grep -q 'Load Addr: 0X8A200000' inventory.txt
                grep -q 'Load Addr: 0X90200000' inventory.txt
                grep -q 'Load Addr: 0X8C000000' inventory.txt
                test "$(grep -c 'A core Image' inventory.txt)" -eq 3
                if grep -Eq 'M7|CORE_CM7' inventory.txt; then
                  echo "unexpected M7 application payload in source-built container" >&2
                  exit 1
                fi

                touch "$out"
              '';

            m7-source-container-structure =
              pkgs.runCommand "frdm-imx95-m7-source-container-structure" {
                allowSubstitutes = false;
                preferLocalBuild = true;
                meta = {
                  hydraPlatforms = [];
                };
              } ''
                ${imxMkimage}/bin/mkimage_imx8 \
                  -soc IMX9 \
                  -parse \
                  "${m7SourceBootContainer}/${m7SourceBootContainer.fileName}" \
                  > inventory.txt

                grep -q 'IMAGE 1 (ELE FW)' inventory.txt
                grep -q 'IMAGE 2 (DDR Init)' inventory.txt
                grep -q 'IMAGE 3 (M33)' inventory.txt
                grep -q 'CORE_CM33' inventory.txt
                grep -q 'IMAGE 4 (Bootloader)' inventory.txt
                grep -q 'CORE_CA55' inventory.txt
                test "$(grep -c 'A core Image' inventory.txt)" -eq 3
                if grep -Eq 'M7|CORE_CM7' inventory.txt; then
                  echo "unexpected M7 application payload in remoteproc boot container" >&2
                  exit 1
                fi

                touch "$out"
              '';

            source-container-reproducibility =
              pkgs.runCommand "frdm-imx95-source-container-reproducibility" {
                allowSubstitutes = false;
                preferLocalBuild = true;
                meta = {
                  hydraPlatforms = [];
                };
              } ''
                cmp \
                  "${sourceBootContainerReproA}/${sourceBootContainerReproA.fileName}" \
                  "${sourceBootContainerReproB}/${sourceBootContainerReproB.fileName}"
                touch "$out"
              '';

            m7-remoteproc-dtb =
              pkgs.runCommand "frdm-imx95-m7-remoteproc-dtb" {
                nativeBuildInputs = [
                  pkgs.dtc
                  pkgs.gnutar
                  pkgs.xz
                ];
              } ''
                m7Dtb=${m7Board.config.hardware.deviceTree.package}/freescale/imx95-15x15-frdm.dtb
                baselineDtb=${board.config.hardware.deviceTree.package}/freescale/imx95-15x15-frdm.dtb
                kernelSrc=${m7Board.config.boot.kernelPackages.kernel.src}
                tar -xOf "$kernelSrc" --wildcards '*/drivers/remoteproc/imx_rproc.c' \
                  > imx_rproc.c

                dtc -I dtb -O dts "$m7Dtb" > m7.dts
                grep -q 'compatible = "fsl,imx95-cm7"' m7.dts
                grep -q 'mbox-names = "tx", "rx", "rxdb"' m7.dts
                grep -q 'memory-region = ' m7.dts

                test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88000000 reg)" =                 "0 88000000 0 8000"
                test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88008000 reg)" =                 "0 88008000 0 8000"
                test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88010000 reg)" =                 "0 88010000 0 8000"
                test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88018000 reg)" =                 "0 88018000 0 8000"
                test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88020000 reg)" =                 "0 88020000 0 100000"
                test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88220000 reg)" =                 "0 88220000 0 1000"

                set -- $(fdtget -t x "$m7Dtb" /imx95-cm7 mboxes)
                test "$#" -eq 9
                set -- $(fdtget -t x "$m7Dtb" /imx95-cm7 memory-region)
                test "$#" -eq 6

                grep -q                 '{ 0x00000000, 0x203C0000, 0x00040000, ATT_OWN | ATT_IOMEM }'                 imx_rproc.c
                grep -q                 '{ 0x20000000, 0x20400000, 0x00040000, ATT_OWN | ATT_IOMEM }'                 imx_rproc.c

                test $(( ${release.m7.remoteproc.tcm.code.systemAddress} + ${release.m7.remoteproc.tcm.code.size} ))                 -le $(( ${release.m7.remoteproc.tcm.data.systemAddress} ))
                test $(( ${m7Vring0.address} + ${m7Vring0.size} ))                 -le $(( ${m7Vring1.address} ))
                test $(( ${m7Vring1.address} + ${m7Vring1.size} ))                 -le $(( ${m7Vring2.address} ))
                test $(( ${m7Vring2.address} + ${m7Vring2.size} ))                 -le $(( ${m7Vring3.address} ))
                test $(( ${m7Vring3.address} + ${m7Vring3.size} ))                 -le $(( ${release.m7.remoteproc.sharedMemory.vdevBuffer.address} ))
                test $(( ${release.m7.remoteproc.sharedMemory.vdevBuffer.address} + ${release.m7.remoteproc.sharedMemory.vdevBuffer.size} ))                 -le $(( ${release.m7.remoteproc.sharedMemory.resourceTable.address} ))

                dtc -I dtb -O dts "$baselineDtb" > baseline.dts
                if grep -q 'compatible = "fsl,imx95-cm7"' baseline.dts; then
                  echo "M7 remoteproc unexpectedly entered the baseline device tree" >&2
                  exit 1
                fi

                touch "$out"
              '';

            required-dtb = pkgs.runCommand "frdm-imx95-required-dtb" {} ''
              test -f \
                ${board.config.hardware.deviceTree.package}/freescale/imx95-15x15-frdm.dtb
              touch "$out"
            '';

            boot-artifacts = pkgs.runCommand "frdm-imx95-boot-artifacts" {} ''
                mkdir -p "$out"
                mkdir work
                cd work
                ln -s "$out" firmware
                ${board.config.sdImage.populateFirmwareCommands}

                test -f "$out/extlinux/extlinux.conf"
              grep -q '^  LINUX ../nixos/' "$out/extlinux/extlinux.conf"
              grep -q '^  INITRD ../nixos/' "$out/extlinux/extlinux.conf"
              grep -q '^  FDT ../nixos/' "$out/extlinux/extlinux.conf"
                    test -n "$(find "$out/nixos" -path '*/freescale/imx95-15x15-frdm.dtb' -print -quit)"
            '';

            source-sd-image-layout =
              pkgs.runCommand "frdm-imx95-source-sd-image-layout" {
                nativeBuildInputs = [
                  pkgs.coreutils
                  pkgs.util-linux
                  pkgs.zstd
                ];
                allowSubstitutes = false;
                preferLocalBuild = true;
                meta = {
                  hydraPlatforms = [];
                };
              } ''
                image=$(echo ${sourceSdImage}/sd-image/*.img.zst)
                zstd --decompress --stdout "$image" > image.img

                dd if=image.img bs=1 skip=${toString sourceBootContainerOffsetBytes} \
                  count=${toString configuredSourceBootContainer.expectedSize} \
                  status=none | \
                  cmp - \
                    "${configuredSourceBootContainer}/${configuredSourceBootContainer.fileName}"

                firstStart=$(sfdisk --json image.img | \
                  ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].start')
                test "$firstStart" -eq $(( ${toString firmwareOffsetBytes} / 512 ))
                test $(( ${toString sourceBootContainerOffsetBytes} + ${toString configuredSourceBootContainer.expectedSize} )) \
                  -lt ${toString ubootEnvironmentOffsetBytes}

                mkdir "$out"
                sha256sum image.img > "$out/image.sha256"
              '';

            sd-image-layout =
              pkgs.runCommand "frdm-imx95-sd-image-layout" {
                nativeBuildInputs = [
                  pkgs.coreutils
                  pkgs.e2fsprogs
                  pkgs.mtools
                  pkgs.util-linux
                  pkgs.zstd
                ];
              } ''
                image=$(echo ${compatibilitySdImage}/sd-image/*.img.zst)
                zstd --decompress --stdout "$image" > image.img

                firstStart=$(sfdisk --json image.img |
                  ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].start')
                secondStart=$(sfdisk --json image.img |
                  ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[1].start')
                firstBootable=$(sfdisk --json image.img |
                  ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].bootable')
                secondBootable=$(sfdisk --json image.img |
                  ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[1].bootable // false')

                test "$firstStart" -eq $(( ${toString firmwareOffsetBytes} / 512 ))
                test "$secondStart" -eq $(( ${toString rootOffsetBytes} / 512 ))
                test "$firstBootable" = true
                test "$secondBootable" = false

                dd if=image.img bs=1 skip=${toString compatibilityBootContainerOffsetBytes} \
                  count=${toString compatibilityBoard.config.hardware.boards.imx95.bootContainerSizeBytes} \
                  status=none |
                  cmp - \
                    "${compatibilityBootContainer}/${compatibilityBootContainerName}"

                dd if=image.img bs=1 skip=${toString compatibilityUbootEnvironmentOffsetBytes} \
                  count=${toString compatibilityBoard.config.hardware.boards.imx95.ubootEnvironmentSizeBytes} \
                  status=none > uboot.env
                grep -a -q 'bootcmd=bootflow scan -lb' uboot.env
                grep -a -q 'boot_targets=mmc1 mmc0' uboot.env
                grep -a -q 'boot_prefixes=/' uboot.env
                grep -a -q 'fdt_addr_r=0x95000000' uboot.env
                grep -a -q 'ramdisk_addr_r=0x98000000' uboot.env

                mtype -i image.img@@${toString firmwareOffsetBytes} \
                  ::/extlinux/extlinux.conf > extlinux.conf
                grep -q '^  LINUX ../nixos/' extlinux.conf
                grep -q '^  INITRD ../nixos/' extlinux.conf
                grep -q '^  FDT ../nixos/' extlinux.conf

                rootLabel=$(blkid -p -O ${toString rootOffsetBytes} \
                  -s LABEL -o value image.img)
                test "$rootLabel" = NIXOS_SD

                mkdir "$out"
                cp extlinux.conf "$out/"
                sfdisk --json image.img > "$out/partition-table.json"
                sha256sum image.img > "$out/image.sha256"
              '';
          }
          // {
            all-features-module-composition = pkgs.runCommand "frdm-imx95-all-features-module-composition" {} ''
              test ${lib.escapeShellArg allFeaturesBoard.config.boot.kernelPackages.kernel.providerKind} = \
                nxp-full-combined
              test ${lib.escapeShellArg allFeaturesBoard.config.hardware.boards.imx95.wave6.providerKind} = \
                nxp-full-combined
              test ${lib.escapeShellArg allFeaturesBoard.config.hardware.deviceTree.name} = \
                freescale/imx95-15x15-frdm.dtb
              test ${
                if
                  allFeaturesBoard.config.boot.initrd.availableKernelModules
                  == [
                    "mmc_block"
                    "sdhci"
                    "sdhci-esdhc-imx"
                  ]
                then "1"
                else "0"
              } = 1
              test ${
                if
                  lib.any
                  (overlay: overlay.name == "frdm-imx95-m7-remoteproc")
                  allFeaturesBoard.config.hardware.deviceTree.overlays
                then "0"
                else "1"
              } = 1
              test ${
                if allFeaturesBoard.config.system.build.runtime.allowSubstitutes
                then "0"
                else "1"
              } = 1
              test ${
                if allFeaturesBoard.config.system.build.firmware.allowSubstitutes
                then "0"
                else "1"
              } = 1
              test ${
                if
                  allFeaturesBoard.config.system.build.smoke.outPath
                  == allFeaturesBoard.config.system.build.neutronSmoke.outPath
                then "1"
                else "0"
              } = 1
              touch "$out"
            '';

            all-features-image-policy = pkgs.runCommand "frdm-imx95-all-features-image-policy" {} ''
              test ${
                if allFeaturesSdImage.allowSubstitutes
                then "0"
                else "1"
              } = 1
              test ${
                if allFeaturesSdImage.preferLocalBuild
                then "1"
                else "0"
              } = 1
              test ${
                if (allFeaturesSdImage.meta.license.redistributable or false)
                then "0"
                else "1"
              } = 1
              test ${toString (builtins.length allFeaturesSdImage.meta.hydraPlatforms)} -eq 0
              touch "$out"
            '';

            neutron-image-policy = pkgs.runCommand "frdm-imx95-neutron-image-policy" {} ''
              test ${
                if neutronSdImage.allowSubstitutes
                then "0"
                else "1"
              } = 1
              test ${
                if neutronSdImage.preferLocalBuild
                then "1"
                else "0"
              } = 1
              test ${
                if (neutronSdImage.meta.license.redistributable or false)
                then "0"
                else "1"
              } = 1
              test ${toString (builtins.length neutronSdImage.meta.hydraPlatforms)} -eq 0
              test ${
                if
                  neutronBoard.config.hardware.boards.imx95.bootContainer.outPath
                  == board.config.hardware.boards.imx95.bootContainer.outPath
                then "1"
                else "0"
              } = 1
              test ${lib.escapeShellArg neutronBoard.config.boot.kernelPackages.kernel.providerKind} = \
                reduced-mainline
              test ${lib.escapeShellArg neutronBoard.config.hardware.deviceTree.name} = \
                freescale/imx95-15x15-frdm.dtb
              touch "$out"
            '';
          };
      }
    );
}
