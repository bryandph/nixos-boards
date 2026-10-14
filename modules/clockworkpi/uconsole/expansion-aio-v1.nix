# HackerGadgets AIO v1 expansion board: GPS, RTL-SDR, LoRa and RTC.
# https://wiki.clockworkpi.com/uconsole/extension-board
{config, ...}: {
  flake.modules.nixos.uconsole-expansion-aio-v1 = {
    lib,
    pkgs,
    ...
  }: {
    hardware.boards.claims =
      map (resource: {
        inherit resource;
        owner = "uconsole-expansion-aio-v1";
      }) [
        # GPS: NMEA on UART0 (GPIO14/15), PPS on GPIO6.
        "gpio:14"
        "gpio:15"
        "gpio:6"
        # LoRa SX1262 on SPI1 with one chip select (GPIO18–21).
        "gpio:18"
        "gpio:19"
        "gpio:20"
        "gpio:21"
        # PCF85063A real-time clock.
        "i2c_csi_dsi0:0x51"
      ];

    # config.txt [pi5] overlays.
    hardware.raspberry-pi.extra-config = lib.concatStrings [
      ''
        [pi5]
        dtparam=uart0
        dtoverlay=pps-gpio,gpiopin=6
      ''
      ''
        [pi5]
        dtoverlay=spi1-1cs
      ''
      ''
        [pi5]
        dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi0
      ''
    ];

    # UART0 (ttyAMA0) carries NMEA; PPS on GPIO6 for time sync. The core
    # keeps console=ttyAMA0 off the kernel command line.
    services = {
      gpsd = {
        enable = true;
        devices = ["/dev/ttyAMA0"];
        listenany = lib.mkDefault false;
        nowait = true;
      };
      udev = {
        extraRules = ''
          KERNEL=="ttyAMA0", SYMLINK+="gps0", GROUP="dialout", MODE="0660"
          KERNEL=="pps0", SYMLINK+="gpspps0", GROUP="dialout", MODE="0660"
        '';
        # mkDefault: a radio stack may provide its own rules.
        packages = lib.mkDefault [pkgs.rtl-sdr];
      };
    };

    # Let the userspace rtl-sdr driver claim the RTL2832U instead of the
    # DVB driver. mkDefault: a radio stack may blacklist more modules.
    boot.blacklistedKernelModules = lib.mkDefault ["dvb_usb_rtl28xxu"];

    environment.systemPackages = [
      pkgs.libgpiod
      pkgs.pps-tools
      pkgs.gpsd
      pkgs.rtl-sdr
      pkgs.i2c-tools
    ];
  };

  flake.nixosModules.uconsole-expansion-aio-v1 = config.flake.modules.nixos.uconsole-expansion-aio-v1;
}
