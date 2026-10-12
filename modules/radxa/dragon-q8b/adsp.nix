{config, ...}: {
  flake.modules.nixos.dragon-q8b-adsp = {pkgs, ...}: let
    adsp = config.boards.lib.mkArtifact {
      inherit pkgs;
      manifest = config.boards.manifests.dragon-q8b-firmware;
      id = "adsp";
    };
  in {
    hardware.firmware = [adsp];
    hardware.boards.artifacts = [adsp];
    hardware.boards.claims = [
      {
        resource = "remoteproc:adsp";
        owner = "dragon-q8b-adsp";
      }
    ];
  };
  flake.nixosModules.dragon-q8b-adsp = config.flake.modules.nixos.dragon-q8b-adsp;
}
