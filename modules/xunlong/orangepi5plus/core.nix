# Orange Pi 5 Plus (RK3588) on the mainline kernel and the upstream device
# tree. Not verified on hardware.
{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588;
in {
  flake.modules.nixos.orangepi5plus-core = {
    imports = [soc-rk3588];

    hardware.boards.identity = {
      board = "orangepi5plus";
      vendor = "xunlong";
      soc = "rk3588";
      bootChain = "image";
      provider = "mainline";
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/Orange-Pi-5-Plus";
    };

    boot.kernelParams = [
      "rootwait"
      "earlycon"
      "consoleblank=0"
      "console=ttyS2,1500000"
      "console=tty1"
    ];

    hardware.deviceTree = {
      enable = true;
      filter = "rk3588-orangepi-5-plus.dtb";
      name = "rockchip/rk3588-orangepi-5-plus.dtb";
    };
  };

  flake.nixosModules.orangepi5plus-core = config.flake.modules.nixos.orangepi5plus-core;
}
