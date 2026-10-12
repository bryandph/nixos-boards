{config, ...}: let
  inherit (config.flake.modules) nixos;
in {
  flake.modules.nixos.dragon-q8b-core = {
    config,
    lib,
    ...
  }: {
    imports = [nixos.hardware-boards nixos.dragon-q8b-provider-radxa];
    nixpkgs.hostPlatform = "aarch64-linux";
    hardware.boards.identity = {
      board = "dragon-q8b";
      vendor = "radxa";
      soc = "sc8280xp";
      bootChain = "board";
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/Dragon-Q8B";
    };
    # Never pull a whole vendor firmware collection into a public closure.
    hardware.enableRedistributableFirmware = lib.mkDefault false;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
    boot.loader.efi.efiSysMountPoint = "/boot";
    boot.kernelParams = ["console=ttyMSM0,115200n8" "earlycon" "clk_ignore_unused"];
    boot.initrd.availableKernelModules = ["sdhci_msm" "nvme" "ufs_qcom" "phy_qcom_qmp_pcie"];
    hardware.boards.connectors = {
      header = {
        standard = "rpi-40pin";
        bindings = {
          uart0-tx = "tlmm:63";
          uart0-rx = "tlmm:64";
        };
      };
      nvme = {
        standard = "m2-m";
        bindings.pcie = "pcie3a";
      };
      nvme2 = {
        standard = "m2-m";
        bindings.pcie = "pcie3b";
      };
      wireless = {
        standard = "m2-e";
        bindings.pcie = "pcie4";
      };
    };
    hardware.boards.claims = [
      {
        resource = "header:8";
        owner = "dragon-q8b-core";
      }
      {
        resource = "header:10";
        owner = "dragon-q8b-core";
      }
    ];
    assertions = [
      {
        assertion = config.hardware.deviceTree.kernelPackage == config.boot.kernelPackages.kernel;
        message = "dragon-q8b: DT package must be the selected kernel (same provider and source)";
      }
    ];
  };
  flake.nixosModules.dragon-q8b-core = config.flake.modules.nixos.dragon-q8b-core;
}
