{config, ...}: let
  pin = (import ../../../packages/radxa/dragon-q8b/sources.nix).radxa;
in {
  flake.modules.nixos.dragon-q8b-provider-radxa = {
    pkgs,
    lib,
    ...
  }: {
    hardware.boards.identity.provider = lib.mkDefault pin.provider;
    boot.kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor (
      config.boards.lib.withProvider pin.provider
      (pkgs.callPackage ../../../packages/radxa/dragon-q8b/linux.nix {})
    ));
    hardware.deviceTree = {
      enable = lib.mkDefault true;
      name = lib.mkDefault "qcom/sc8280xp-radxa-dragon-q8b.dtb";
    };
  };
  flake.nixosModules.dragon-q8b-provider-radxa = config.flake.modules.nixos.dragon-q8b-provider-radxa;
}
