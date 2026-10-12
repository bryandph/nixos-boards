{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588-image;
in {
  flake.modules.nixos.orangepi5plus-image = {pkgs, ...}: {
    imports = [soc-rk3588-image];
    hardware.boards.rk3588.image = {
      uboot = pkgs.ubootOrangePi5Plus;
      rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
    };
  };

  flake.nixosModules.orangepi5plus-image = config.flake.modules.nixos.orangepi5plus-image;
}
