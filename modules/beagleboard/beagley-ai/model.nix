# RegNetX-200MF compiled for the J722S C7x with TI's x86 TIDL tools.
# Built from R2 inputs: import them first with
# `nix run .#beagley-ai-import-artifacts`.
{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.beagley-ai-regnet-model = {
    config,
    pkgs,
    ...
  }: let
    x86 = beagley (import pkgs.path {
      system = "x86_64-linux";
      inherit (pkgs) config;
    });
    modelTools = x86.callPackage ../../../packages/beagleboard/beagley-ai/model-tools.nix {};
    model = x86.callPackage ../../../packages/beagleboard/beagley-ai/model-regnet.nix {inherit modelTools;};
  in {
    environment.systemPackages = [model];
    environment.pathsToLink = ["/share/beagley-ai/models"];
    hardware.boards.artifacts = [model];
  };

  flake.nixosModules.beagley-ai-regnet-model = config.flake.modules.nixos.beagley-ai-regnet-model;
}
