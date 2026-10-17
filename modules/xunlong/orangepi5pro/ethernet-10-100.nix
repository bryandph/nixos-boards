# The YT6801 on this PCB does not complete 1000BASE-T link training: each
# link event spends about 14 s on gigabit before falling back to 100 Mbps.
# Advertising only 10/100 brings the link up in about 2 s.
#
# systemd matches Driver= against ID_NET_DRIVER, which is the ethtool
# driver name. The YT6801 binds to the dwmac-motorcomm PCI driver, but
# stmmac reports `st_gmac` through ethtool. The board DTS enables no
# on-SoC GMAC, so `st_gmac` is the YT6801 alone.
{config, ...}: {
  flake.modules.nixos.orangepi5pro-ethernet-10-100 = {pkgs, ...}: {
    environment.systemPackages = [pkgs.ethtool];

    systemd.network.links."10-orangepi5pro-yt6801" = {
      matchConfig.Driver = "st_gmac";
      linkConfig = {
        AutoNegotiation = true;
        Advertise = "10baset-half 10baset-full 100baset-half 100baset-full";
      };
    };
  };

  flake.nixosModules.orangepi5pro-ethernet-10-100 = config.flake.modules.nixos.orangepi5pro-ethernet-10-100;
}
