# BeagleY-AI packages for maintainers and checks, built with nixpkgs that
# admits exactly the board's manifest names. Board features build their own
# packages with the consumer's nixpkgs instead.
{
  config,
  inputs,
  lib,
  ...
}: let
  beagley = import ./_scope.nix {inherit config;};
  boardsLib = config.boards.lib;
  manifest = config.boards.manifests.beagley-ai;
  dir = ../../../packages/beagleboard/beagley-ai;
in {
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.unfreePackages [manifest]);
    };
    native = beagley pkgs;
    cross = beagley pkgs.pkgsCross.aarch64-multiplatform;
  in {
    boardPackages.beagley-ai =
      lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        boot-bundle = native.callPackage (dir + "/boot-bundle.nix") {};
        boot-firmware = native.callPackage (dir + "/boot-firmware.nix") {};
        uboot-r5 = native.callPackage (dir + "/uboot.nix") {stage = "r5";};
        uboot-a53 = native.callPackage (dir + "/uboot.nix") {};
        arm-trusted-firmware = native.callPackage (dir + "/arm-trusted-firmware.nix") {};
        optee = native.callPackage (dir + "/optee.nix") {};
        kernel = cross.callPackage (dir + "/linux.nix") {};
        wireless-firmware = native.callPackage (dir + "/wireless-firmware.nix") {};
        codec-firmware = native.callPackage (dir + "/multimedia-firmware.nix") {};
        ipc-firmware = native.callPackage (dir + "/accelerator-ipc-firmware.nix") {};
        ipc-test = cross.callPackage (dir + "/accelerator-ipc-test.nix") {};
        pvr-mesa = cross.callPackage (dir + "/multimedia-mesa.nix") {};
        rogue-userspace = cross.callPackage (dir + "/multimedia-rogue-userspace.nix") {};
        rogue-kmod = cross.callPackage (dir + "/multimedia-rogue-kmod.nix") {
          kernel = cross.callPackage (dir + "/linux.nix") {};
        };
        accelerator-runtime = cross.callPackage (dir + "/accelerator-runtime.nix") {};
        ti-rpmsg-char = cross.callPackage (dir + "/accelerator-rpmsg.nix") {};
        tidl = cross.callPackage (dir + "/accelerator-tidl.nix") {};
        osrt = cross.callPackage (dir + "/accelerator-osrt.nix") {};
        edgeai-libraries = cross.callPackage (dir + "/multimedia-edgeai-libraries.nix") {};
        edgeai-gstreamer = cross.callPackage (dir + "/multimedia-edgeai-gstreamer.nix") {};
        imx219-dcc = cross.callPackage (dir + "/multimedia-imx219-dcc.nix") {};
        camera = cross.callPackage (dir + "/multimedia-camera.nix") {};
      }
      // lib.optionalAttrs (system == "x86_64-linux") (let
        modelTools = native.callPackage (dir + "/model-tools.nix") {};
      in
        {
          accelerator-firmware = native.callPackage (dir + "/accelerator-firmware.nix") {};
          model-tools = modelTools;
          regnet-model = native.callPackage (dir + "/model-regnet.nix") {inherit modelTools;};
        }
        // lib.genAttrs ["accelerator-armllvm" "accelerator-c7000" "accelerator-sysconfig"] (name:
          native.callPackage (dir + "/accelerator-tool.nix") {
            tool = lib.removePrefix "accelerator-" name;
          }));
  };
}
