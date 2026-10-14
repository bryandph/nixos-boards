# HackerGadgets NVMe adapter and battery board: an M.2 NVMe slot on the
# CM5's PCIe x1 lane.
# https://hackergadgets.com/products/nvme
{config, ...}: {
  flake.modules.nixos.uconsole-expansion-nvme = {
    hardware.boards.claims = [
      {
        resource = "pcie1:x1";
        owner = "uconsole-expansion-nvme";
      }
    ];

    hardware.raspberry-pi.extra-config = ''
      [pi5]
      dtparam=pciex1
    '';
  };

  flake.nixosModules.uconsole-expansion-nvme = config.flake.modules.nixos.uconsole-expansion-nvme;
}
