# Radxa ROCK 5A (RK3588S) on the mainline kernel and the upstream device
# tree. Not verified on hardware.
{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588;
in {
  flake.modules.nixos.rock5a-core = {
    imports = [soc-rk3588];

    hardware.boards.identity = {
      board = "rock5a";
      vendor = "radxa";
      soc = "rk3588s";
      bootChain = "image";
      provider = "mainline";
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/ROCK-5A";
    };

    boot.kernelParams = [
      "rootwait"
      "earlycon"
      "consoleblank=0"
      "console=ttyS2,1500000n8"
      "console=tty0"
    ];

    hardware.deviceTree = {
      enable = true;
      filter = "rk3588s-rock-5a.dtb";
      name = "rockchip/rk3588s-rock-5a.dtb";
    };
  };

  flake.nixosModules.rock5a-core = config.flake.modules.nixos.rock5a-core;
}
