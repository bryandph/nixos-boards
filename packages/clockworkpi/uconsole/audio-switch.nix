# Speaker/headphone switch. Reimplements the Debian image's
# clockworkpi-audio-patch.service with libgpiod.
{
  writeShellApplication,
  libgpiod,
  coreutils,
  pollInterval ? "1",
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

    # libgpiod 2's gpioset holds the line until it exits, and the value is
    # not guaranteed after that. Keep one gpioset running in the background
    # and replace it only when the wanted value changes.
    holder=""
    current=""
    release() {
      if [ -n "$holder" ]; then
        kill "$holder" 2>/dev/null || true
        wait "$holder" 2>/dev/null || true
        holder=""
      fi
      current=""
    }
    trap release EXIT
    trap 'exit 0' TERM INT

    echo "uconsole-audio: starting speaker/headphone switch"

    while true; do
      val=$(gpioget --numeric "$HP_LINE")
      if [ "$val" = "0" ]; then
        want=1  # no headphone — speaker on
      else
        want=0  # headphone inserted — speaker off
      fi
      # Retry if the holder died (for example, the line was busy).
      if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
        release
      fi
      if [ "$want" != "$current" ]; then
        release
        gpioset --consumer uconsole-audio "$SPK_LINE=$want" &
        holder=$!
        current=$want
      fi
      sleep ${pollInterval}
    done
  '';
}
