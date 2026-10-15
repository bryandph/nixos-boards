# TI OpenVX/vision-apps runtime, TIDL and the OSRT Python runtimes for the
# C7x accelerators. Built from R2 inputs: import them first with
# `nix run .#beagley-ai-import-artifacts`.
{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.beagley-ai-accelerator-runtime = {pkgs, ...}: let
    scope = beagley pkgs;
    packages = map (file: scope.callPackage (../../../packages/beagleboard/beagley-ai + "/${file}") {}) [
      "accelerator-runtime.nix"
      "accelerator-tidl.nix"
      "accelerator-osrt.nix"
    ];
  in {
    environment.systemPackages = packages;
    hardware.boards.artifacts = packages;
  };

  flake.nixosModules.beagley-ai-accelerator-runtime = config.flake.modules.nixos.beagley-ai-accelerator-runtime;
}
