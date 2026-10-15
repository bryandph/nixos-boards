# Image-owned boot chain (D4): R5 and A53 U-Boot stages with TF-A, OP-TEE
# and TI's TIFS and Device Manager firmware, written to the image's boot
# partition. Non-free (TI Text File License).
{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.beagley-ai-boot-bundle = {
    config,
    pkgs,
    ...
  }: let
    bundle = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/boot-bundle.nix {};
  in {
    hardware.boards.artifacts = [bundle];
    sdImage.populateFirmwareCommands = ''
      cp ${bundle}/{tiboot3.bin,tispl.bin,u-boot.img} firmware/
      cp -r ${bundle}/share firmware/
    '';
    system.build.beagleyAiBootBundle = bundle;
    # The image layout check needs the boot files.
    system.build.beagleyAiSdImageCheck = pkgs.callPackage ../../../packages/beagleboard/beagley-ai/sd-image-check.nix {
      image = config.system.build.beagleyAiSdImage;
      configurationLimit = config.boot.loader.generic-extlinux-compatible.configurationLimit;
    };
  };

  flake.nixosModules.beagley-ai-boot-bundle = config.flake.modules.nixos.beagley-ai-boot-bundle;
}
