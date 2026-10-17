# Turn off the board's two PWM LEDs. The upstream DTS gives them no label,
# so the LED class names them <color>:<function>.
{config, ...}: {
  flake.modules.nixos.orangepi5pro-leds-off = {
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="blue:status", ATTR{trigger}="none", ATTR{brightness}="0"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="green:activity", ATTR{trigger}="none", ATTR{brightness}="0"
    '';
  };

  flake.nixosModules.orangepi5pro-leds-off = config.flake.modules.nixos.orangepi5pro-leds-off;
}
