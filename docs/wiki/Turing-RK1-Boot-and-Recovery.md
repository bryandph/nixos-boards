# Turing RK1: boot and recovery

The image is uncompressed because the Turing Pi 2 BMC flashes raw images (`tpi flash`). U-Boot is nixpkgs' `ubootTuringRK1`. To recover a module, power it off from the BMC and flash a known-good image through the BMC.

The boot chain, image layout (version 1) and recovery are shared by the
RK3588 boards; see [Rockchip RK3588](SoC-RK3588).
