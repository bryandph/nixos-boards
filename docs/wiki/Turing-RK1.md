# Turing RK1

The [Turing RK1](https://turingpi.com/product/turing-rk1/) is an RK3588 compute module in the SO-DIMM form factor for the Turing Pi 2. Its console is UART9, routed to the Turing Pi 2 BMC at 115200 baud (`console=ttyS9`); the kernel registers 16 8250 UARTs so that ttyS9 exists.

| Feature | Provides |
| --- | --- |
| `turing-rk1-core` | Mainline kernel through `soc-rk3588`, the upstream device tree and console |
| `turing-rk1-image` | SD/eMMC image (`soc-rk3588-image`, layout version 1) |

```nix
imports = with inputs.nixos-boards.nixosModules; [
  turing-rk1-core
  turing-rk1-image
];
```

Build `config.system.build.sdImage`. The board needs no release manifest:
U-Boot's TPL and TF-A come from nixpkgs and runtime firmware from
linux-firmware. Status of each function: [hardware matrix](Turing-RK1-Hardware-Matrix).
Boot chain, layout and recovery: [boot and recovery](Turing-RK1-Boot-and-Recovery)
and [Rockchip RK3588](SoC-RK3588).
