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
    orangepi5pro = {
      page = "Orange-Pi-5-Pro";
      free = with nixos; [
        orangepi5pro-core
        orangepi5pro-image
        orangepi5pro-ethernet-10-100
        orangepi5pro-leds-off
      ];
      haveHardware = true;
      functions =
        lib.mapAttrs (_: features: {
          status = "implemented-unverified";
          inherit features;
        }) {
          boot = ["orangepi5pro-image"];
          serial-console = ["orangepi5pro-core"];
          ethernet = ["orangepi5pro-core" "orangepi5pro-ethernet-10-100"];
          nvme = ["orangepi5pro-core"];
          emmc = ["orangepi5pro-image"];
          cpu-dvfs = ["orangepi5pro-core"];
          gpu = ["orangepi5pro-core"];
          leds = ["orangepi5pro-core" "orangepi5pro-leds-off"];
        }
        // lib.mapAttrs (_: reason: {
          status = "implemented-unverified";
          inherit reason;
          features = ["orangepi5pro-core"];
        }) {
          # soc-rk3588's redistributable firmware includes nixpkgs'
          # raspberrypi-wireless-firmware; linux-firmware has neither file.
          wifi = "brcmfmac43456-sdio firmware from nixpkgs raspberrypi-wireless-firmware; its NVRAM is the Raspberry Pi's, not AP6256 calibration";
          bluetooth = "BCM4345C5.hcd from nixpkgs raspberrypi-wireless-firmware";
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

        orangepi5pro-console-contract = let
          c = config.flake.nixosConfigurations.orangepi5pro-free.config;
          consoles = lib.filter (lib.hasPrefix "console=") c.boot.kernelParams;
        in
          assert lib.last consoles == "console=ttyS2,1500000";
          assert builtins.elem "earlycon" c.boot.kernelParams;
          assert builtins.elem "phy-rockchip-naneng-combphy" c.boot.initrd.availableKernelModules;
            pkgs.writeText "orangepi5pro-console-contract" "Upstream UART2/1.5M console and PCIe2 PHY initrd request evaluated; no hardware acceptance.\n";

        # The board DTS is first in Linux 7.3, so orangepi5pro-core uses
        # linuxPackages_testing while linuxPackages_latest is older. This
        # fails once nixpkgs' latest reaches 7.3: then delete the override
        # in modules/xunlong/orangepi5pro/core.nix and this check.
        orangepi5pro-kernel = let
          nixos = config.flake.nixosConfigurations.orangepi5pro-free;
          inherit (nixos.config.boot.kernelPackages) kernel;
          testing = nixos.pkgs.linuxPackages_testing.kernel;
          latest = nixos.pkgs.linuxPackages_latest.kernel.version;
        in
          assert lib.assertMsg (lib.versionOlder latest "7.3") "linuxPackages_latest is ${latest}: drop the linuxPackages_testing override in orangepi5pro-core";
          assert kernel.provider == "mainline";
          assert kernel.outPath == testing.outPath;
            pkgs.writeText "orangepi5pro-kernel" "orangepi5pro boots nixpkgs' linuxPackages_testing kernel ${kernel.version} unchanged (${kernel.outPath}).\n";
      }
      // lib.optionalAttrs (system == "aarch64-linux") (lib.genAttrs' ["turing-rk1" "orangepi5" "orangepi5pro" "orangepi5plus" "rock5a"] (board:
        lib.nameValuePair "${board}-device-tree" (let
          c = config.flake.nixosConfigurations."${board}-free".config;
        in
          pkgs.runCommand "${board}-device-tree" {} ''
            test -s ${c.hardware.deviceTree.package}/${c.hardware.deviceTree.name}
            touch "$out"
          '')));
  };
}
