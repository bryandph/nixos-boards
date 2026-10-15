# Orange Pi 5

The Orange Pi 5 (RK3588S) runs the mainline kernel and the upstream `rk3588s-orangepi-5.dtb`: GMAC Ethernet with the Motorcomm YT8531 PHY, PCIe/NVMe, CPU DVFS and the debug UART. No vendor provider is offered: the vendor kernel's NPU, VPU and Mali power domains raise an asynchronous SError on headless boots of this board.

| Feature | Provides |
| --- | --- |
| `orangepi5-core` | Mainline kernel through `soc-rk3588`, the upstream device tree and console |
| `orangepi5-image` | SD/eMMC image (`soc-rk3588-image`, layout version 1) |

```nix
imports = with inputs.nixos-boards.nixosModules; [
  orangepi5-core
  orangepi5-image
];
```

Build `config.system.build.sdImage`. The board needs no release manifest:
U-Boot's TPL and TF-A come from nixpkgs and runtime firmware from
linux-firmware. Status of each function: [hardware matrix](Orange-Pi-5-Hardware-Matrix).
Boot chain, layout and recovery: [boot and recovery](Orange-Pi-5-Boot-and-Recovery)
and [Rockchip RK3588](SoC-RK3588).
