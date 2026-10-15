# Orange Pi 5 Plus

The Orange Pi 5 Plus (RK3588) runs the mainline kernel and the upstream `rk3588-orangepi-5-plus.dtb`. It has not been verified on hardware.

| Feature | Provides |
| --- | --- |
| `orangepi5plus-core` | Mainline kernel through `soc-rk3588`, the upstream device tree and console |
| `orangepi5plus-image` | SD/eMMC image (`soc-rk3588-image`, layout version 1) |

```nix
imports = with inputs.nixos-boards.nixosModules; [
  orangepi5plus-core
  orangepi5plus-image
];
```

Build `config.system.build.sdImage`. The board needs no release manifest:
U-Boot's TPL and TF-A come from nixpkgs and runtime firmware from
linux-firmware. Status of each function: [hardware matrix](Orange-Pi-5-Plus-Hardware-Matrix).
Boot chain, layout and recovery: [boot and recovery](Orange-Pi-5-Plus-Boot-and-Recovery)
and [Rockchip RK3588](SoC-RK3588).
