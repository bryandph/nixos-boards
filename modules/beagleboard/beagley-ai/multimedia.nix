{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
in {
  # Wave521C video codec and E5010 JPEG encoder (non-free codec firmware).
  flake.modules.nixos.beagley-ai-multimedia = {pkgs, ...}: let
    codec = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/multimedia-firmware.nix {};
  in {
    hardware.firmware = [codec];
    hardware.boards.artifacts = [codec];
    environment.systemPackages = [(pkgs.v4l-utils.override {withGUI = false;}) pkgs.ffmpeg];
  };

  # PowerVR Rogue GPU: free kernel module and Mesa, non-free userspace and
  # GPU firmware.
  flake.modules.nixos.beagley-ai-gpu = {
    config,
    pkgs,
    ...
  }: let
    userspace = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/multimedia-rogue-userspace.nix {};
    mesa = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/multimedia-mesa.nix {};
  in {
    boot.extraModulePackages = [(config.boot.kernelPackages.callPackage ../../../packages/beagleboard/beagley-ai/multimedia-rogue-kmod.nix {})];
    boot.kernelModules = ["pvrsrvkm"];
    hardware.firmware = [userspace];
    hardware.boards.artifacts = [userspace];
    hardware.graphics = {
      enable = true;
      package = mesa;
      extraPackages = [userspace];
    };
    environment.systemPackages = [userspace pkgs.clinfo pkgs.vulkan-tools pkgs.mesa-demos pkgs.alsa-utils];
  };

  flake.nixosModules = {
    inherit (config.flake.modules.nixos) beagley-ai-multimedia beagley-ai-gpu;
  };
}
