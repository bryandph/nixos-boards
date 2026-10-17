{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588-image;
in {
  flake.modules.nixos.orangepi5pro-image = {pkgs, ...}: {
    imports = [soc-rk3588-image];
    hardware.boards.rk3588.image = {
      uboot = pkgs.callPackage ../../../packages/xunlong/orangepi5pro/u-boot.nix {};
      firmwareSize = 512; # kernel, initrd and DTB for several generations
    };
  };

  flake.nixosModules.orangepi5pro-image = config.flake.modules.nixos.orangepi5pro-image;

  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    boardPackages = lib.optionalAttrs (system == "aarch64-linux") {
      orangepi5pro.u-boot = pkgs.callPackage ../../../packages/xunlong/orangepi5pro/u-boot.nix {};
    };
  };
}
