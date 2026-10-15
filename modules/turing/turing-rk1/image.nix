# Raw (uncompressed) image, because the Turing Pi 2 BMC flashes .img files
# directly. U-Boot is nixpkgs' ubootTuringRK1.
{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588-image;
in {
  flake.modules.nixos.turing-rk1-image = {pkgs, ...}: {
    imports = [soc-rk3588-image];
    hardware.boards.rk3588.image = {
      uboot = pkgs.ubootTuringRK1;
      compress = false;
      rootPartitionUUID = "0bf70c3b-50f8-4f22-8254-2eaf50f1f7b7";
    };
  };

  flake.nixosModules.turing-rk1-image = config.flake.modules.nixos.turing-rk1-image;
}
