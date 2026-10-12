# Source-assembled NXP boot container (U-Boot, TF-A, OP-TEE, System Manager,
# OEI) with NXP's ELE and LPDDR4X training firmware. Non-free (R2): import
# the firmware with `nix run .#frdm-imx95-import-nxp-firmware` first.
{config, ...}: let
  frdm = import ./_scope.nix {inherit config;};
  inherit (config.flake.modules.nixos) frdm-imx95-image;
in {
  flake.modules.nixos.frdm-imx95-boot-container = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [frdm-imx95-image];
    hardware.boards.imx95.bootContainer = lib.mkDefault ((frdm pkgs).sourceBootContainer.override {
      expectedBootContainerSha256 = config.hardware.boards.imx95.sourceBootContainerSha256;
    });
    hardware.boards.artifacts = lib.optional (config.hardware.boards.imx95.bootContainer ? manifestEntry) config.hardware.boards.imx95.bootContainer;
  };

  flake.nixosModules.frdm-imx95-boot-container = config.flake.modules.nixos.frdm-imx95-boot-container;
}
