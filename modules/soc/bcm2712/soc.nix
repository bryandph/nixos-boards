# Raspberry Pi 5 / CM5 (BCM2712) boot chain from nixos-raspberrypi
# (upstream first, D12). Mirrors nixos-raspberrypi's raspberry-pi-5 base
# module, which reads `nixos-raspberrypi` as a module argument; here the
# input is taken from the flake, so consumers pass nothing in.
{
  config,
  inputs,
  ...
}: let
  rpi = inputs.nixos-raspberrypi;
in {
  flake.modules.nixos.soc-bcm2712 = {
    lib,
    pkgs,
    ...
  }: let
    rpiPackages = rpi.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    key = "nixos-boards#soc-bcm2712";
    imports = [
      "${rpi}/modules/raspberrypi.nix"
      {
        key = "nixos-boards#nixos-raspberrypi-overlays";
        imports = [rpi.lib.inject-overlays];
      }
    ];

    boot.loader.raspberry-pi = {
      variant = "5";
      bootloader = lib.mkDefault "kernelboot";
      firmwarePackage = lib.mkDefault rpiPackages.raspberrypifw;
    };
    boot.kernelPackages = lib.mkDefault rpiPackages.linuxPackages_rpi5;
    boot.initrd.availableKernelModules = [
      "nvme" # NVMe drive connected through PCIe
    ];
  };

  flake.nixosModules.soc-bcm2712 = config.flake.modules.nixos.soc-bcm2712;
}
