{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588-image;
in {
  flake.modules.nixos.orangepi5-image = {pkgs, ...}: {
    imports = [soc-rk3588-image];
    hardware.boards.rk3588.image = {
      uboot = pkgs.ubootOrangePi5;
      firmwareSize = 512; # kernel, initrd and DTB for several generations
    };
  };

  flake.nixosModules.orangepi5-image = config.flake.modules.nixos.orangepi5-image;
}
