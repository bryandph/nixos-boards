# Speaker/headphone switch. Reimplements the Debian image's
# clockworkpi-audio-patch.service with libgpiod.
{
  writeShellApplication,
  libgpiod,
  coreutils,
}:
writeShellApplication {
  name = "uconsole-audio-switch";
  runtimeInputs = [
    libgpiod
    coreutils
  ];
  text = ''
    # Address lines by name (resolved across all chips) rather than a chip
    # number — the main GPIO bank's gpiochipN index is not stable across
    # kernels (it moved from gpiochip4 to gpiochip0/pinctrl-rp1).
    HP_LINE="GPIO10"   # headphone detect (input): 0 = none, 1 = inserted
    SPK_LINE="GPIO11"  # speaker amp enable (output): 1 = on, 0 = off

    echo "uconsole-audio: starting speaker/headphone switch"

    while true; do
      val=$(gpioget --numeric "$HP_LINE")
      if [ "$val" = "0" ]; then
        gpioset "$SPK_LINE"=1  # no headphone — speaker on
      else
        gpioset "$SPK_LINE"=0  # headphone inserted — speaker off
      fi
      sleep 1
    done
  '';
}
