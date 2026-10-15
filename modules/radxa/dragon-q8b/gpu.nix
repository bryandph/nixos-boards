{config, ...}: {
  flake.modules.nixos.dragon-q8b-gpu = {pkgs, ...}: let
    artifacts = map (id:
      config.boards.lib.mkArtifact {
        inherit pkgs id;
        manifest = config.boards.manifests.dragon-q8b-firmware;
      }) ["gpu-sqe" "gpu-gmu" "gpu-zap"];
  in {
    hardware.graphics.enable = true;
    hardware.firmware = artifacts;
    hardware.boards.artifacts = artifacts;
    hardware.boards.claims = [
      {
        resource = "soc:gpu";
        owner = "dragon-q8b-gpu";
      }
    ];
  };
  flake.nixosModules.dragon-q8b-gpu = config.flake.modules.nixos.dragon-q8b-gpu;
}
