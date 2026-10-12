# FRDM-i.MX95 package scope, built from the consumer's nixpkgs. Packages
# call `frdmArtifact` (an artifact from the release manifest) and
# `frdmBuilt` (register a package built from manifest inputs).
{config}: let
  boardsLib = config.boards.lib;
  manifest = config.boards.manifests.frdm-imx95;
  dir = ../../../packages/nxp/frdm-imx95;
in
  pkgs:
    pkgs.lib.makeScope pkgs.newScope (self: {
      frdmArtifact = id: boardsLib.mkArtifact {inherit pkgs manifest id;};
      frdmBuilt = id: package: boardsLib.mkBuilt {inherit manifest id package;};
      release = import (dir + "/imx95-lf-6.18.20-2.0.0.nix") {inherit (pkgs) lib;};

      # Boot chain.
      uboot = self.callPackage (dir + "/uboot-imx95-frdm.nix") {};
      armTrustedFirmware = self.callPackage (dir + "/imx-atf-imx95.nix") {};
      optee = self.callPackage (dir + "/imx-optee-os-imx95.nix") {};
      systemManager = self.callPackage (dir + "/imx-system-manager-imx95.nix") {};
      oei = self.callPackage (dir + "/imx-oei-imx95-frdm.nix") {};
      imxMkimage = self.callPackage (dir + "/imx-mkimage-imx95.nix") {};
      licensedFirmware = self.callPackage (dir + "/imx95-licensed-firmware.nix") {};
      sourceBootContainer = self.callPackage (dir + "/imx95-source-boot-container.nix") {};
      m7SourceBootContainer = self.callPackage (dir + "/imx95-source-boot-container.nix") {remoteprocMode = true;};
      completeBootContainer = self.callPackage (dir + "/nxp-imx95-boot-container.nix") {};

      # Kernels.
      allFeaturesKernel = self.callPackage (dir + "/linux-imx95-all-features.nix") {};
      wave6Kernel = self.callPackage (dir + "/linux-imx95-wave6.nix") {};
      neutronReferenceKernel = self.callPackage (dir + "/linux-imx95-neutron.nix") {};
      neutronReducedKernel = self.callPackage (dir + "/linux-imx95-neutron-reduced.nix") {};

      # Firmware and runtimes.
      wave6Firmware = self.callPackage (dir + "/nxp-imx95-wave6-firmware.nix") {};
      neutronRuntime = self.callPackage (dir + "/imx95-neutron-runtime.nix") {};
      modelSource = self.callPackage (dir + "/imx95-neutron-model-source.nix") {};
      tensorflowLite = self.callPackage (dir + "/tensorflow-lite-imx95.nix") {};
      delegateSource = self.callPackage (dir + "/tflite-neutron-delegate-source.nix") {};
      delegate = self.callPackage (dir + "/tflite-neutron-delegate-imx95.nix") {
        runtime = self.neutronRuntime;
        source = self.delegateSource;
      };

      # Tools and hardware smoke runners.
      m7Ctl = self.callPackage (dir + "/frdm-imx95-m7-ctl.nix") {};
      gpuSmoke = self.callPackage (dir + "/frdm-imx95-gpu-smoke-runner.nix") {};
      jpegSmoke = self.callPackage (dir + "/frdm-imx95-jpeg-smoke-runner.nix") {};
      wave6Smoke = self.callPackage (dir + "/frdm-imx95-wave6-smoke-runner.nix") {};
      audioSmoke = self.callPackage (dir + "/frdm-imx95-audio-smoke-runner.nix") {};
      nvmeSmoke = self.callPackage (dir + "/frdm-imx95-nvme-smoke-runner.nix") {};
      neutronSmokeRunner = self.callPackage (dir + "/frdm-imx95-neutron-smoke-runner.nix") {};
      importNeutronRuntime = self.callPackage (dir + "/import-imx95-neutron-runtime.nix") {};
      convertNeutronModel = self.callPackage (dir + "/convert-imx95-neutron-model.nix") {};
      eiqNeutronSdk = self.callPackage (dir + "/eiq-neutron-sdk.nix") {};
    })
