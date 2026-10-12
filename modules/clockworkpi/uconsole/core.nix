# ClockworkPi uConsole with a CM5 (Lite) compute module: kernel, firmware
# configuration, display, audio switching and battery protection.
{
  config,
  inputs,
  ...
}: let
  boardsLib = config.boards.lib;
  inherit (config.flake.modules) nixos;
  rpi = inputs.nixos-raspberrypi;
in {
  flake.modules.nixos.uconsole-core = {
    lib,
    pkgs,
    ...
  }: let
    uconsoleKernel = import ../../../packages/clockworkpi/uconsole/kernel.nix {inherit lib;};
    base = rpi.packages.${pkgs.stdenv.hostPlatform.system}.linux_rpi5;
    provider = "rpi-${lib.versions.majorMinor base.version}";
    kernel = boardsLib.withProvider provider (uconsoleKernel.withOverlayReadme base);
    audioSwitch = pkgs.callPackage ../../../packages/clockworkpi/uconsole/audio-switch.nix {};
  in {
    imports = [
      nixos.hardware-boards
      nixos.soc-bcm2712
      # CM5 on-module Bluetooth.
      "${rpi}/modules/bluetooth.nix"
    ];

    hardware.boards = {
      identity = {
        board = "uconsole";
        vendor = "clockworkpi";
        soc = "bcm2712";
        bootChain = "vendor-partition";
        inherit provider;
        statusPage = "https://github.com/bryandph/nixos-boards/wiki/uConsole";
      };
      connectors.expansion = {
        standard = "uconsole-expansion";
        bindings = {
          uart = "uart0";
          spi = "spi1";
          i2c = "i2c_csi_dsi0";
          pcie = "pcie1";
        };
      };
      claims = map (resource: {
        inherit resource;
        owner = "uconsole-core";
      }) ["gpio:10" "gpio:11" "gpio:12" "gpio:13"];
    };

    # mkForce over the SoC's mkDefault of the unpatched kernel.
    boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernel);
    boot.kernelPatches = uconsoleKernel.patches;

    boot = {
      # mkForce: the uConsole has no serial debug header, so
      # console=ttyAMA0 (added by nixos-raspberrypi's sd-image) is never
      # useful and would corrupt GPS NMEA data on the AIO board.
      # Consumers add parameters with lib.mkForce as well; NixOS merges
      # same-priority lists.
      kernelParams = lib.mkForce [
        "console=tty1"
        "fbcon=rotate:1" # portrait-mounted DSI display
        "quiet" # keep boot/systemd console spam off the greeter
      ];
      kernelModules = ["i2c-dev"];
      # ZFS is not needed on the uConsole; avoid the heavy build dependency.
      supportedFilesystems.zfs = lib.mkForce false;
    };

    # I2C for RTC, sensors, etc.
    hardware.i2c.enable = true;

    # ── config.txt [all] section ─────────────────────────────────────
    hardware.raspberry-pi.config.all = {
      options = {
        ignore_lcd = {
          enable = true;
          value = 1;
        };
        max_framebuffers = {
          enable = true;
          value = 2;
        };
        disable_overscan = {
          enable = true;
          value = 1;
        };
        # The uConsole has a custom DSI panel (panel-cwu50) and no
        # camera; probing for standard displays and cameras is pointless.
        camera_auto_detect = {
          enable = true;
          value = 0;
        };
        display_auto_detect = {
          enable = true;
          value = 0;
        };
      };
      base-dt-params = {
        audio = {
          enable = true;
          value = "on";
        };
        ant2 = {
          enable = true;
        };
      };
      dt-overlays = {
        # The Pi 4 vc4-kms-v3d overlay is incompatible with BCM2712. On
        # CM5, [all] and [pi5] both apply; vc4-kms-v3d-pi5 is in [pi5].
        # Loading the Pi 4 version corrupts pinctrl register mappings on
        # D0 silicon.
        vc4-kms-v3d.enable = false;
        audremap = {
          enable = true;
          params.pins_12_13 = {
            enable = true;
          };
        };
        # dwc2 is already added in [cm5] by nixos-raspberrypi; do not
        # duplicate it in [all], as both sections apply on CM5.
      };
    };

    # ── config.txt [pi5] section ─────────────────────────────────────
    # The structured config module does not support conditional sections.
    hardware.raspberry-pi.extra-config = ''
      [pi5]
      dtoverlay=clockworkpi-uconsole-cm5
      dtoverlay=vc4-kms-v3d-pi5,cma-384
    '';

    # Speaker amplifier off while headphones are inserted (GPIO10 detect,
    # GPIO11 amplifier enable).
    systemd.services.uconsole-audio-switch = {
      description = "uConsole speaker/headphone auto-switch via GPIO";
      after = ["systemd-modules-load.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${audioSwitch}/bin/uconsole-audio-switch";
        Restart = "always";
        RestartSec = "5";
      };
    };

    # Low-battery protection. The AXP228's hardware cutoff (V_OFF, from
    # the DT battery node's voltage-min-design) is 2.9 V. Under load the
    # CM5 browns out and wedges before the battery sags that far, leaving
    # every PMIC rail enabled and the charger cycling against the wedged
    # load; only removing the batteries recovers it. upowerd performs
    # criticalPowerAction itself (no desktop needed), so an orderly
    # poweroff runs axp20x_power_off(), the PMIC latches off cleanly, and
    # charging while off works.
    services.upower = {
      enable = true;
      usePercentageForPolicy = true;
      percentageLow = 15;
      percentageCritical = 10;
      # Margin above the gauge's jumpy near-empty region; the AXP228
      # percentage register is uncalibrated near 0%.
      percentageAction = 8;
      criticalPowerAction = "PowerOff";
    };
  };

  flake.nixosModules.uconsole-core = config.flake.modules.nixos.uconsole-core;
}
