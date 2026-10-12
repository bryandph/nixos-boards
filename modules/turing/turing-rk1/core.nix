# Turing RK1 (RK3588 compute module, SO-DIMM) on the mainline kernel.
# UART9 is routed through the SO-DIMM to the Turing Pi 2 BMC at 115200;
# UART2 is on test pads only.
{config, ...}: let
  inherit (config.flake.modules.nixos) soc-rk3588;
in {
  flake.modules.nixos.turing-rk1-core = {lib, ...}: {
    imports = [soc-rk3588];

    hardware.boards.identity = {
      board = "turing-rk1";
      vendor = "turing";
      soc = "rk3588";
      bootChain = "image";
      provider = "mainline";
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/Turing-RK1";
    };

    boot = {
      # The 8250 driver registers 8 UARTs by default; UART9 (the BMC
      # console) needs ttyS9, or console=ttyS9 silently fails and the
      # board reset-loops on the watchdog after kernel handoff.
      kernelPatches = [
        {
          name = "rk3588-bump-8250-nr-uarts";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            SERIAL_8250_NR_UARTS = freeform "16";
            SERIAL_8250_RUNTIME_UARTS = freeform "16";
          };
        }
      ];

      # mkForce over sd-image-aarch64's console defaults. No root=: the
      # root comes from fileSystems."/" (by label), and a second root
      # definition breaks systemd stage 1.
      kernelParams = lib.mkForce [
        "rootwait"
        # Bare earlycon takes the clock from the device tree; an explicit
        # uart8250 address assumes 1.8432 MHz and garbles the BMC console.
        "earlycon"
        "keep_bootcon"
        "console=ttyS9,115200"
        "loglevel=7"
        "net.ifnames=0" # classic eth0 naming for the GMAC
        # cgroup v1 compatibility for k3s
        "cgroup_enable=cpuset"
        "cgroup_memory=1"
        "cgroup_enable=memory"
        "swapaccount=1"
      ];
    };

    hardware.deviceTree = {
      name = "rockchip/rk3588-turing-rk1.dtb";
      # The mainline arm64 build ships every board's DTB, which would not
      # fit the firmware partition.
      filter = "*rk3588*";
      overlays = [];
    };
  };

  flake.nixosModules.turing-rk1-core = config.flake.modules.nixos.turing-rk1-core;
}
