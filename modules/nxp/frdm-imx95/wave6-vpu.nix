# Wave6 H.264/HEVC VPU with the NXP reference kernel and NXP's codec
# firmware (R2, built from the imported firmware-imx distribution).
{
  config,
  lib,
  ...
}: let
  frdm = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.frdm-imx95-wave6-vpu = {
    config,
    pkgs,
    ...
  }: let
    scope = frdm pkgs;
    inherit (scope) release;
    delta = release.multimedia.wave6.kernelDelta;
    kernel = scope.wave6Kernel;
    providerKind = config.boot.kernelPackages.kernel.providerKind or "upstream";
    nixosKernel =
      kernel
      // {
        override = override:
          kernel.kernelOverride (
            if builtins.isFunction override
            then
              override {
                features = kernel.features;
                kernelPatches = kernel.kernelPatches;
                randstructSeed = "";
              }
            else override
          );
      };
    firmware = scope.wave6Firmware;
    smoke = scope.wave6Smoke;
    deviceTreePackage = pkgs.runCommand "frdm-imx95-wave6-device-tree" {} ''
      install -Dm0444 \
        ${kernel}/dtbs/${kernel.wave6Dtb} \
        "$out/freescale/imx95-15x15-frdm.dtb"
    '';
  in {
    options.hardware.boards.imx95.wave6 = {
      providerKind = lib.mkOption {
        type = lib.types.enum [
          "full-nxp-reference"
          "nxp-full-combined"
        ];
        readOnly = true;
        description = "Evidence-selected release-pinned Wave6 kernel provider.";
      };
      firmwareMember = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Only licensed firmware member installed by the Wave6 role.";
      };
    };

    config = {
      hardware.boards.identity.provider = lib.mkForce kernel.provider;
      hardware.boards.artifacts = [firmware];
      hardware.boards.imx95.wave6 = {
        providerKind =
          if providerKind == "nxp-full-combined"
          then providerKind
          else delta.providerSelection.selected;
        firmwareMember = release.multimedia.wave6.firmware.member.fileName;
      };
      boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor nixosKernel);
      hardware.deviceTree.package =
        lib.mkIf (providerKind != "nxp-full-combined") (lib.mkForce deviceTreePackage);
      hardware.firmware = [firmware];
      hardware.firmwareCompression = "none";
      users.groups.video = {};
      services.udev.extraRules = ''
        SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", DRIVERS=="wave6-vpu", GROUP="video", MODE="0660"
      '';
      environment.systemPackages = [
        smoke
        pkgs.v4l-utils
      ];
      system.build = {
        inherit deviceTreePackage firmware smoke;
        wave6DeviceTreePackage = deviceTreePackage;
        wave6Smoke = smoke;
      };
      assertions = [
        {
          assertion =
            providerKind
            == delta.providerSelection.selected
            || providerKind == "nxp-full-combined";
          message = ''
            Wave6 requires either its explicitly selected release provider or
            the reviewed combined NXP provider.
          '';
        }
        {
          assertion =
            config.hardware.deviceTree.name
            == delta.deviceTree.selectedDtb;
          message = "Wave6 must preserve the accepted FRDM DT filename.";
        }
        {
          assertion = !firmware.manifestEntry.redistribution.cache;
          message = "Wave6 firmware must remain non-redistributable.";
        }
        {
          assertion = firmware.allowSubstitutes == false;
          message = "Wave6 firmware must not be substituted.";
        }
      ];
    };
  };

  flake.nixosModules.frdm-imx95-wave6-vpu = config.flake.modules.nixos.frdm-imx95-wave6-vpu;
}
