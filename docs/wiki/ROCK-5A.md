# ROCK 5A

The Radxa ROCK 5A (RK3588S) runs the mainline kernel and the upstream `rk3588s-rock-5a.dtb`. It has not been verified on hardware.

| Feature | Provides |
| --- | --- |
| `rock5a-core` | Mainline kernel through `soc-rk3588`, the upstream device tree and console |
| `rock5a-image` | SD/eMMC image (`soc-rk3588-image`, layout version 1) |

```nix
imports = with inputs.nixos-boards.nixosModules; [
  rock5a-core
  rock5a-image
];
```

Build `config.system.build.sdImage`. The board needs no release manifest:
U-Boot's TPL and TF-A come from nixpkgs and runtime firmware from
linux-firmware. Status of each function: [hardware matrix](ROCK-5A-Hardware-Matrix).
Boot chain, layout and recovery: [boot and recovery](ROCK-5A-Boot-and-Recovery)
and [Rockchip RK3588](SoC-RK3588).
