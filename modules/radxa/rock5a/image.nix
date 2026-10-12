{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588-image;
in {
  flake.modules.nixos.rock5a-image = {pkgs, ...}: {
    imports = [soc-rk3588-image];
    hardware.boards.rk3588.image = {
      uboot = pkgs.callPackage ../../../packages/radxa/rock5a/u-boot.nix {};
      rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
    };
  };

  flake.nixosModules.rock5a-image = config.flake.modules.nixos.rock5a-image;
}
