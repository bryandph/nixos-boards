# Public source pins; board-owned firmware is a version requirement, not a fetch.
{
  radxa = {
    version = "7.0.11";
    rev = "a50eb5b71984bd82b49cd5d31b1e2eb5505c6512";
    hash = "sha256-wDtFADvJOYKKmOEbN7XKQbkIXC9hJKCtAd6qs90EMfY=";
    provider = "radxa-7.0.11";
  };
  uefi = {
    # Observed in the vendor OS boot log; NixOS compatibility remains unverified.
    version = "6.0.260818.BOOT.MXF.1.1.c1-00167-MAKENA-1";
    source = "https://docs.radxa.com/en/dragon/q8b/download";
    ownership = "board";
  };
}
