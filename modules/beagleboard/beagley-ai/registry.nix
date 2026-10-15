{
  config,
  lib,
  ...
}: let
  inherit (config.flake.modules) nixos;
  data = import ../../../packages/beagleboard/beagley-ai/manifest.nix {};
  status = s: features: {
    status = s;
    inherit features;
  };
in {
  boards.manifests.beagley-ai = data.manifest;

  boards.registry.beagley-ai = {
    page = "BeagleY-AI";
    free = [nixos.beagley-ai-core nixos.beagley-ai-image];
    full = [nixos.beagley-ai-full nixos.beagley-ai-regnet-model];
    manifests = ["beagley-ai"];
    haveHardware = true;
    functions = {
      boot = status "implemented-unverified" ["beagley-ai-boot-bundle"];
      serial-console = status "implemented-unverified" ["beagley-ai-core"];
      ethernet = status "implemented-unverified" ["beagley-ai-core"];
      sd-card = status "implemented-unverified" ["beagley-ai-image"];
      usb-gadget = status "implemented-unverified" ["beagley-ai-usb-gadget"];
      header-routing = status "implemented-unverified" ["beagley-ai-header-uart1" "beagley-ai-header-spi0" "beagley-ai-header-mcasp0"];
      video-codec = status "implemented-unverified" ["beagley-ai-multimedia"];
      gpu = status "implemented-unverified" ["beagley-ai-gpu"];
      wifi-ble = status "implemented-unverified" ["beagley-ai-wireless"];
      c7x-vision = status "implemented-unverified" ["beagley-ai-vision" "beagley-ai-accelerator-runtime"];
      ipc-echo = status "implemented-unverified" ["beagley-ai-remoteproc-ipc"];
      camera = status "implemented-unverified" ["beagley-ai-csi0-imx219" "beagley-ai-camera"];
      displays = status "implemented-unverified" ["beagley-ai-dsi-rpi-7inch" "beagley-ai-oldi-lcd185"];
      regnet-model = status "implemented-unverified" ["beagley-ai-regnet-model"];
    };
  };

  perSystem = {pkgs, ...}: {
    apps.beagley-ai-import-artifacts = {
      type = "app";
      meta.description = "Import the BeagleY-AI's operator-supplied (R2) artifacts after accepting their terms";
      program = lib.getExe (config.boards.lib.mkImportTool {
        inherit pkgs;
        name = "beagley-ai-import-artifacts";
        manifests = [config.boards.manifests.beagley-ai];
      });
    };
  };
}
