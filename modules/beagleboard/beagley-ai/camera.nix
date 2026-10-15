# IMX219 camera pipeline (EdgeAI GStreamer plugins, DCC tuning, OSRT).
# The package is MIT, but it is built against the accelerator stack, so it
# is only available in the full profile.
{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.beagley-ai-camera = {pkgs, ...}: let
    scope = beagley pkgs;
    built = map (file: scope.callPackage (../../../packages/beagleboard/beagley-ai + "/${file}") {}) [
      "multimedia-edgeai-libraries.nix"
      "multimedia-edgeai-gstreamer.nix"
      "multimedia-imx219-dcc.nix"
    ];
  in {
    environment.systemPackages = [(scope.callPackage ../../../packages/beagleboard/beagley-ai/multimedia-camera.nix {})];
    hardware.boards.artifacts = built;
  };

  flake.nixosModules.beagley-ai-camera = config.flake.modules.nixos.beagley-ai-camera;
}
