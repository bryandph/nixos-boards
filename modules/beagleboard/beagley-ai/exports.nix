# Free BeagleY-AI add-on and connector features.
{
  config,
  lib,
  ...
}: {
  flake.nixosModules = lib.genAttrs ([
      "beagley-ai-usb-gadget"
      "beagley-ai-oldi-lcd185"
      "beagley-ai-csi0-imx219"
      "beagley-ai-csi1-imx219"
      "beagley-ai-dsi-rpi-7inch"
    ]
    ++ map (name: "beagley-ai-header-${name}") ["gpio14-15" "uart1" "i2c-400khz" "spi0" "pwm14" "pwm12" "mcasp0"])
  (name: config.flake.modules.nixos.${name});
}
