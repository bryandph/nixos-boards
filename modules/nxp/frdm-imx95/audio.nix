{config, ...}: let
  frdm = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.frdm-imx95-audio = {
    config,
    pkgs,
    ...
  }: let
    audioSmoke = (frdm pkgs).audioSmoke;
    kernel = config.boot.kernelPackages.kernel;
    providerKind = kernel.providerKind or "upstream";
  in {
    users.groups.audio = {};
    environment.systemPackages = [
      audioSmoke
      pkgs.alsa-utils
    ];
    system.build.audioSmoke = audioSmoke;

    assertions = [
      {
        assertion =
          providerKind
          != "nxp-full-combined"
          || builtins.elem "audio" kernel.capabilities;
        message = "The combined NXP kernel must advertise the FRDM audio capability.";
      }
    ];
  };

  flake.nixosModules.frdm-imx95-audio = config.flake.modules.nixos.frdm-imx95-audio;
}
