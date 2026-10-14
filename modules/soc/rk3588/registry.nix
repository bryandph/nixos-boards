# The mainline RK3588 boards. They need no release manifests: U-Boot's TPL
# and TF-A come from nixpkgs (rkbin is unfreeRedistributableFirmware, which
# nixpkgs counts as free), and runtime firmware from linux-firmware.
{
  config,
  lib,
  ...
}: let
  inherit (config.flake.modules) nixos;
in {
  boards.registry = {
    turing-rk1 = {
      page = "Turing-RK1";
      free = [nixos.turing-rk1-core nixos.turing-rk1-image];
      haveHardware = true;
      functions =
        lib.mapAttrs (_: features: {
          status = "implemented-unverified";
          inherit features;
        }) {
          boot = ["turing-rk1-image"];
          bmc-console = ["turing-rk1-core"];
          ethernet = ["turing-rk1-core"];
          nvme = ["turing-rk1-core"];
          emmc = ["turing-rk1-image"];
        };
    };
    orangepi5 = {
      page = "Orange-Pi-5";
      free = [nixos.orangepi5-core nixos.orangepi5-image];
      haveHardware = true;
      functions =
        lib.mapAttrs (_: features: {
          status = "implemented-unverified";
          inherit features;
        }) {
          boot = ["orangepi5-image"];
          serial-console = ["orangepi5-core"];
          ethernet = ["orangepi5-core"];
          nvme = ["orangepi5-core"];
          cpu-dvfs = ["orangepi5-core"];
        };
    };
    orangepi5plus = {
      page = "Orange-Pi-5-Plus";
      free = [nixos.orangepi5plus-core nixos.orangepi5plus-image];
      functions =
        lib.mapAttrs (_: features: {
          status = "pending";
          inherit features;
        }) {
          boot = ["orangepi5plus-image"];
          serial-console = ["orangepi5plus-core"];
          ethernet = ["orangepi5plus-core"];
        };
    };
    rock5a = {
      page = "ROCK-5A";
      free = [nixos.rock5a-core nixos.rock5a-image];
      functions =
        lib.mapAttrs (_: features: {
          status = "pending";
          inherit features;
        }) {
          boot = ["rock5a-image"];
          serial-console = ["rock5a-core"];
          ethernet = ["rock5a-core"];
        };
    };
  };

  # Device-tree contract: the DTB each board boots is built by its kernel.
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks =
      {
        orangepi5-console-contract = let
          c = config.flake.nixosConfigurations.orangepi5-free.config;
          consoles = lib.filter (lib.hasPrefix "console=") c.boot.kernelParams;
        in
          assert lib.last consoles == "console=ttyS2,1500000n8";
          assert builtins.elem "earlycon" c.boot.kernelParams;
          assert builtins.elem "phy-rockchip-naneng-combphy" c.boot.initrd.availableKernelModules;
            pkgs.writeText "orangepi5-console-contract" "Pinned upstream UART2/1.5M console and PCIe2 PHY initrd request evaluated; no hardware acceptance.\n";
      }
      // lib.optionalAttrs (system == "aarch64-linux") (lib.genAttrs' ["turing-rk1" "orangepi5" "orangepi5plus" "rock5a"] (board:
        lib.nameValuePair "${board}-device-tree" (let
          c = config.flake.nixosConfigurations."${board}-free".config;
        in
          pkgs.runCommand "${board}-device-tree" {} ''
            test -s ${c.hardware.deviceTree.package}/${c.hardware.deviceTree.name}
            touch "$out"
          '')));
  };
}
