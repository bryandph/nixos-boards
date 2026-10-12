{config, ...}: let
  frdm = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.frdm-imx95-nvme = {
    config,
    pkgs,
    ...
  }: let
    nvmeSmoke = (frdm pkgs).nvmeSmoke;
    kernel = config.boot.kernelPackages.kernel;
    providerKind = kernel.providerKind or "upstream";
  in {
    environment.systemPackages = [
      nvmeSmoke
      pkgs.nvme-cli
      pkgs.pciutils
    ];
    system.build.nvmeSmoke = nvmeSmoke;

    assertions = [
      {
        assertion =
          providerKind
          != "nxp-full-combined"
          || builtins.elem "nvme" kernel.capabilities;
        message = "The combined NXP kernel must advertise the FRDM NVMe capability.";
      }
    ];
  };

  flake.nixosModules.frdm-imx95-nvme = config.flake.modules.nixos.frdm-imx95-nvme;
}
