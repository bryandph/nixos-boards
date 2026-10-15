# SD-card image layout for the FRDM-i.MX95: raw boot container at 32 KiB,
# U-Boot environment, FAT boot and ext4 root partitions. Free; the boot
# container comes from frdm-imx95-boot-container (non-free) or from the
# consumer through hardware.boards.imx95.bootContainer.
{config, ...}: {
  flake.modules.nixos.frdm-imx95-image = {
    config,
    lib,
    modulesPath,
    pkgs,
    ...
  }: let
    cfg = config.hardware.boards.imx95;
    provider =
      if cfg.bootContainer == null
      then {}
      else cfg.bootContainer;
    requiredProviderMetadata = [
      "bootContainerOffsetKiB"
      "componentManifest"
      "containsM7Application"
      "expectedHash"
      "expectedSha256"
      "expectedSize"
      "fileName"
      "providerKind"
      "providerLicense"
      "release"
      "reservedBootRegionMiB"
      "ubootEnvironmentOffsetKiB"
      "ubootEnvironmentSizeBytes"
    ];
    hasProviderMetadata =
      lib.all (name: builtins.hasAttr name provider) requiredProviderMetadata;
    bootContainerName = provider.fileName or "missing-provider-file-name";
    bootContainerPath =
      if cfg.bootContainer == null
      then
        throw ''
          The FRDM-i.MX95 SD image needs a boot container. Compose
          frdm-imx95-boot-container (built from operator-imported NXP
          firmware) or set hardware.boards.imx95.bootContainer.
        ''
      else "${cfg.bootContainer}/${bootContainerName}";
    offsetBytes = cfg.bootContainerOffsetKiB * 1024;
    environmentOffsetBytes = cfg.ubootEnvironmentOffsetKiB * 1024;
    reservedBytes = cfg.reservedBootRegionMiB * 1024 * 1024;
  in {
    # Imported by the features that set the boot container.
    key = "nixos-boards#frdm-imx95-image";
    imports = [
      # Use the generic assembler: the aarch64 installer profile adds Tegra/
      # QEMU consoles and broad filesystem choices unrelated to this board.
      "${modulesPath}/installer/sd-card/sd-image.nix"
      (let
        base = import "${modulesPath}/profiles/base.nix" {inherit config lib pkgs;};
      in
        base
        // {
          key = "${modulesPath}/profiles/base.nix";
          _file = "${modulesPath}/profiles/base.nix";
          # Retain exactly the installer's recovery tools/host-id defaults, but
          # make its filesystem suggestions lower priority than board/consumer
          # definitions. No consumer definition is filtered or forced away.
          boot =
            base.boot
            // {
              supportedFilesystems = lib.mkDefault base.boot.supportedFilesystems;
            };
        })
    ];

    options.hardware.boards.imx95 = {
      bootContainer = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = ''
          Boot-container provider implementing the FRDM-i.MX95 provider
          metadata contract. frdm-imx95-boot-container sets the source-
          assembled provider; the complete NXP container is selected
          explicitly only for compatibility or recovery. The image build
          fails while this is null.
        '';
      };

      sourceBootContainerSha256 = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "[0-9a-f]{64}");
        default = null;
        description = ''
          Accepted SHA-256 of the source-assembled boot container, or null for
          the release pin. The bytes depend on the toolchain, so consumers on
          another nixpkgs revision record the identity they have accepted.
        '';
      };

      m7BootContainerSha256 = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "[0-9a-f]{64}");
        default = null;
        description = "Accepted SHA-256 of the M7 remoteproc boot container, or null for the release pin.";
      };

      bootContainerOffsetKiB = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared raw SD offset for the i.MX95 boot container.";
      };

      bootContainerSizeBytes = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared size of the selected boot container.";
      };

      ubootEnvironmentOffsetKiB = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared NXP U-Boot raw MMC environment offset.";
      };

      ubootEnvironmentSizeBytes = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared NXP U-Boot raw MMC environment size.";
      };

      reservedBootRegionMiB = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared raw region before the first filesystem partition.";
      };
    };

    config = {
      # Layout 1: boot container at 32 KiB, U-Boot environment at 7 MiB,
      # FAT BOOT from 8 MiB, ext4 NIXOS_SD root.
      hardware.boards.image.layoutVersion = 1;
      hardware.boards.imx95 = {
        bootContainerOffsetKiB = provider.bootContainerOffsetKiB or 1;
        bootContainerSizeBytes = provider.expectedSize or 1;
        reservedBootRegionMiB = provider.reservedBootRegionMiB or 1;
        ubootEnvironmentOffsetKiB = provider.ubootEnvironmentOffsetKiB or 1;
        ubootEnvironmentSizeBytes = provider.ubootEnvironmentSizeBytes or 1;
      };

      assertions = lib.optionals (cfg.bootContainer != null) [
        {
          assertion = hasProviderMetadata;
          message = ''
            The selected FRDM-i.MX95 boot-container package does not implement
            the required provider metadata contract.
          '';
        }
        {
          assertion = (provider.providerLicense.redistributable or true) == false;
          message = ''
            The selected FRDM-i.MX95 boot-container provider must retain the
            non-redistributable NXP license boundary.
          '';
        }
        {
          assertion = offsetBytes + cfg.bootContainerSizeBytes <= reservedBytes;
          message = ''
            The FRDM-i.MX95 boot container would overlap the first filesystem
            partition. Refusing to produce an unsafe SD image.
          '';
        }
        {
          assertion =
            environmentOffsetBytes
            + cfg.ubootEnvironmentSizeBytes
            <= reservedBytes;
          message = ''
            The FRDM-i.MX95 U-Boot environment would overlap the first
            filesystem partition.
          '';
        }
        {
          assertion =
            offsetBytes + cfg.bootContainerSizeBytes <= environmentOffsetBytes;
          message = ''
            The FRDM-i.MX95 boot container would overlap the U-Boot
            environment.
          '';
        }
      ];

      # generic-extlinux-compatible installs generations under /boot. The
      # generic SD-image module's noauto /boot/firmware mount would leave those
      # updates on the root filesystem instead of the FAT boot partition.
      fileSystems."/boot/firmware".enable = lib.mkForce false;
      fileSystems."/boot".enable = lib.mkForce false;

      # SD and eMMC may contain byte-identical images, including duplicate
      # labels and partition UUIDs. Resolve /boot from the device hosting /
      # so udev cannot redirect the mount when the other medium enumerates.
      systemd.generators.frdm-imx95-root-boot =
        pkgs.writeShellScript
        "frdm-imx95-root-boot-generator"
        ''
          outputDirectory="$1"
          rootMajorMinor=$(${lib.getExe' pkgs.util-linux "findmnt"} -nr -o MAJ:MIN /)
          rootSysfs=$(${lib.getExe' pkgs.coreutils "readlink"} -f \
            "/sys/dev/block/$rootMajorMinor")
          parentSysfs=''${rootSysfs%/*}
          bootName=''${parentSysfs##*/}

          case "$bootName" in
            mmcblk*) bootPartition="/dev/''${bootName}p1" ;;
            *) exit 0 ;;
          esac

          ${lib.getExe' pkgs.coreutils "mkdir"} -p \
            "$outputDirectory/local-fs.target.requires"
          ${lib.getExe' pkgs.coreutils "cat"} > "$outputDirectory/boot.mount" <<EOF
          [Unit]
          Description=FRDM-i.MX95 boot partition matching the root device
          Before=local-fs.target

          [Mount]
          What=$bootPartition
          Where=/boot
          Type=vfat
          Options=defaults
          DirectoryMode=0755
          EOF
          ${lib.getExe' pkgs.coreutils "ln"} -s ../boot.mount \
            "$outputDirectory/local-fs.target.requires/boot.mount"
        '';

      sdImage = {
        compressImage = true;
        firmwarePartitionOffset = cfg.reservedBootRegionMiB;
        firmwarePartitionID = "0x95465244";
        firmwarePartitionName = "BOOT";
        firmwareSize = 512;
        rootPartitionUUID = "d4b95ed2-4fbd-45d8-bd74-8ba0f5353e31";
        rootVolumeLabel = "NIXOS_SD";

        populateFirmwareCommands = lib.mkForce ''
          mkdir -p ./firmware
          ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
            -c ${config.system.build.toplevel} -d ./firmware
        '';

        populateRootCommands = lib.mkForce ''
          mkdir -p ./files/boot
        '';

        postBuildCommands = ''
          bootContainer=${lib.escapeShellArg bootContainerPath}
          ${lib.getExe pkgs.bash} \
            ${../../../packages/nxp/frdm-imx95/scripts/check-imx95-boot-container} \
            "$bootContainer" \
            ${lib.escapeShellArg (provider.expectedSha256 or "missing")} \
            ${toString cfg.bootContainerSizeBytes} \
            ${toString offsetBytes} \
            ${toString reservedBytes} \
            ${toString environmentOffsetBytes}

          dd if="$bootContainer" of="$img" bs=1024 \
            seek=${toString cfg.bootContainerOffsetKiB} conv=notrunc,fsync status=none

          cat > uboot.env.txt <<'EOF'
          bootcmd=bootflow scan -lb
          boot_targets=mmc1 mmc0
          bootdelay=2
          boot_prefixes=/
          kernel_addr_r=0x90400000
          fdt_addr_r=0x95000000
          ramdisk_addr_r=0x98000000
          EOF

          ${lib.getExe' pkgs.ubootTools "mkenvimage"} \
            -s ${toString cfg.ubootEnvironmentSizeBytes} \
            -o uboot.env uboot.env.txt
          dd if=uboot.env of="$img" bs=1024 \
            seek=${toString cfg.ubootEnvironmentOffsetKiB} \
            conv=notrunc,fsync status=none

          # NXP U-Boot's bootflow rejects a DOS partition without the active
          # flag. The generic NixOS SD module places that flag on root instead.
          sfdisk --activate "$img" 1
        '';
      };

      systemd.services.expand-root-partition.script = lib.mkForce ''
        rootMajorMinor=$(${lib.getExe' pkgs.util-linux "findmnt"} -nr -o MAJ:MIN /)
        rootSysfs=$(${lib.getExe' pkgs.coreutils "readlink"} -f \
          "/sys/dev/block/$rootMajorMinor")
        rootName=''${rootSysfs##*/}
        parentSysfs=''${rootSysfs%/*}
        bootName=''${parentSysfs##*/}
        partNum=$(${lib.getExe' pkgs.coreutils "cat"} "$rootSysfs/partition")
        rootPart="/dev/$rootName"
        bootDevice="/dev/$bootName"

        echo "Expanding partition $partNum on $bootDevice for root $rootPart"

        echo ",+," | ${lib.getExe' pkgs.util-linux "sfdisk"} \
          -N "$partNum" --no-reread "$bootDevice"
        ${lib.getExe' pkgs.parted "partprobe"}
        ${lib.getExe' pkgs.e2fsprogs "resize2fs"} "$rootPart"
      '';

      system.build.frdmImx95SdImage = config.system.build.sdImage.overrideAttrs (old: {
        allowSubstitutes = false;
        preferLocalBuild = true;
        meta =
          (old.meta or {})
          // {
            description = "NixOS SD image for FRDM-i.MX95 containing licensed NXP firmware";
            hydraPlatforms = [];
            platforms = ["aarch64-linux"];
            sourceProvenance = with lib.sourceTypes; [
              fromSource
              binaryFirmware
              binaryNativeCode
            ];
          };
      });
    };
  };

  flake.nixosModules.frdm-imx95-image = config.flake.modules.nixos.frdm-imx95-image;
}
