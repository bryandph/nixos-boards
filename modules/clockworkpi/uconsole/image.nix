# SD-card image for the uConsole, from nixos-raspberrypi's sd-image.
{
  config,
  inputs,
  ...
}: {
  flake.modules.nixos.uconsole-image = {lib, ...}: {
    imports = ["${inputs.nixos-raspberrypi}/modules/installer/sd-card/sd-image-raspberrypi.nix"];

    # Layout 1: nixos-raspberrypi's firmware partition plus an ext4 root
    # labelled NIXOS_SD.
    hardware.boards.image.layoutVersion = 1;

    # SD-card root; consumers installing elsewhere (e.g. NVMe with disko)
    # define their own fileSystems."/".
    fileSystems."/" = lib.mkDefault {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  flake.nixosModules.uconsole-image = config.flake.modules.nixos.uconsole-image;
}
