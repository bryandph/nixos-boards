# Neutron NPU: the reviewed reduced mainline kernel, NXP's Neutron runtime
# and the TensorFlow Lite delegate (R2), and an acceptance smoke closure.
{config, ...}: let
  frdm = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.frdm-imx95-neutron-npu = {
    config,
    lib,
    pkgs,
    ...
  }: let
    scope = frdm pkgs;
    inherit (scope) release;
    kernel = scope.neutronReducedKernel;
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
    inherit (scope) modelSource delegate;
    tensorflowLite = scope.tensorflowLite.override {
      fetchDepsSha256 = config.hardware.boards.imx95.tensorflowLiteDepsSha256;
    };
    smokeRunner = scope.neutronSmokeRunner;
    runtime = scope.neutronRuntime;
    convertedModel = let
      artifact = scope.frdmArtifact "neutron-converted-model";
    in
      scope.frdmBuilt "neutron-model" (pkgs.runCommand "frdm-imx95-neutron-model" {
          src = "${artifact}/${artifact.manifestEntry.path}";
          allowSubstitutes = false;
          preferLocalBuild = true;
          meta = {
            hydraPlatforms = [];
            platforms = ["aarch64-linux"];
          };
        } ''
          install -Dm0444 "$src" "$out/share/models/${release.neutron.model.converted.fileName}"
        '');
    deviceTreePackage = pkgs.runCommand "frdm-imx95-neutron-device-tree" {} ''
      install -Dm0444 \
        ${kernel}/dtbs/${kernel.neutronDtb} \
        "$out/freescale/imx95-15x15-frdm.dtb"
    '';
    smoke = scope.frdmBuilt "neutron-smoke" (pkgs.writeShellApplication {
      name = "frdm-imx95-neutron-smoke";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        export NEUTRON_BENCHMARK=${tensorflowLite}/bin/benchmark_model_dynamic
        export NEUTRON_CPU_MODEL=${modelSource}/${modelSource.modelPath}
        export NEUTRON_DELEGATE=${delegate}/lib/libneutron_delegate.so
        export NEUTRON_MODEL=${convertedModel}/share/models/${release.neutron.model.name}-neutron.tflite
        export NEUTRON_DEVICE=/dev/neutron0
        export NEUTRON_FIRMWARE=/run/current-system/firmware/NeutronFirmware.elf
        export NEUTRON_PERF_COUNTERS=/sys/kernel/debug/neutron/perf_counters
        export NEUTRON_REPORT="''${NEUTRON_REPORT:-$PWD/frdm-imx95-neutron-smoke.json}"
        exec ${lib.getExe smokeRunner} --require-char-device "$@"
      '';
      derivationArgs = {
        allowSubstitutes = false;
        preferLocalBuild = true;
      };
      meta = {
        description = "Licensed FRDM-i.MX95 Neutron acceptance smoke closure";
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
      };
    });
  in {
    options.hardware.boards.imx95.tensorflowLiteDepsSha256 = lib.mkOption {
      type = lib.types.strMatching "sha256-.+";
      default = "sha256-qnuldxLFIW0hB03Pydo+HhjaIeTDbf6gBhxH0XqxACE=";
      description = "Bazel dependency archive pin for the consumer toolchain; reverify when changing nixpkgs. Does not change artifact licence/cache permission.";
    };
    config = {
      boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor nixosKernel);
      hardware.boards.identity.provider = lib.mkForce kernel.provider;
      hardware.boards.artifacts = [runtime delegate convertedModel smoke];
      hardware.boards.claims = [
        {
          resource = "remoteproc:neutron";
          owner = "frdm-imx95-neutron-npu";
        }
      ];
      hardware.deviceTree.package =
        lib.mkIf (providerKind != "nxp-full-combined") (lib.mkForce deviceTreePackage);
      hardware.firmware = [runtime];
      hardware.firmwareCompression = "none";

      users.groups.neutron = {};
      services.udev.extraRules = ''
        SUBSYSTEM=="neutron", KERNEL=="neutron[0-9]*", GROUP="neutron", MODE="0660"
      '';
      systemd.tmpfiles.rules = [
        "z /sys/kernel/debug/neutron 0750 root neutron - -"
        "z /sys/kernel/debug/neutron/perf_counters 0640 root neutron - -"
      ];

      environment.systemPackages = [
        delegate
        smoke
        tensorflowLite
      ];

      system.build = {
        inherit convertedModel delegate deviceTreePackage runtime smoke;
        neutronDeviceTreePackage = deviceTreePackage;
        neutronSmoke = smoke;
      };

      assertions = [
        {
          assertion = config.hardware.deviceTree.name == "freescale/imx95-15x15-frdm.dtb";
          message = "The Neutron role must preserve the accepted FRDM DT filename.";
        }
        {
          assertion =
            providerKind
            == "reduced-mainline"
            || providerKind == "nxp-full-combined";
          message = ''
            The Neutron role requires either its reviewed reduced provider or
            the reviewed combined NXP provider.
          '';
        }
      ];
    };
  };

  flake.nixosModules.frdm-imx95-neutron-npu = config.flake.modules.nixos.frdm-imx95-neutron-npu;
}
