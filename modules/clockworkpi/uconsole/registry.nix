{
  config,
  lib,
  ...
}: let
  inherit (config.flake.modules) nixos;
in {
  boards.registry.uconsole = {
    page = "uConsole";
    free = [
      nixos.uconsole-core
      nixos.uconsole-image
      nixos.uconsole-expansion-aio-v1
      nixos.uconsole-expansion-nvme
    ];
    haveHardware = true;
    functions =
      lib.mapAttrs (_: features: {
        status = "implemented-unverified";
        inherit features;
      }) {
        display = ["uconsole-core"];
        backlight = ["uconsole-core"];
        audio = ["uconsole-core"];
        battery = ["uconsole-core"];
        wifi = ["uconsole-core"];
        bluetooth = ["uconsole-core"];
        gps = ["uconsole-expansion-aio-v1"];
        rtl-sdr = ["uconsole-expansion-aio-v1"];
        lora = ["uconsole-expansion-aio-v1"];
        rtc = ["uconsole-expansion-aio-v1"];
        nvme = ["uconsole-expansion-nvme"];
      };
  };

  # Device tree contract: every overlay config.txt names is built by the
  # kernel the configuration uses (upstream tree or board patches).
  perSystem = {pkgs, ...}: let
    nixosCfg = config.flake.nixosConfigurations.uconsole-free.config;
    kernel = nixosCfg.boot.kernelPackages.kernel;
    overlays = lib.unique (lib.concatMap (line: let
      m = builtins.match "dtoverlay=([^,]+).*" line;
    in
      lib.optional (m != null) (lib.head m))
    (lib.splitString "\n" nixosCfg.hardware.raspberry-pi.config-generated));
  in {
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      uconsole-device-tree =
        pkgs.runCommand "uconsole-device-tree" {
          inherit (kernel) src;
          patches = map (p: p.patch) (lib.filter (p: p.patch != null) nixosCfg.boot.kernelPatches);
        } ''
          makefile="$src/arch/arm/boot/dts/overlays/Makefile"
          status=0
          for overlay in ${lib.escapeShellArgs overlays}; do
            if grep -q -w -- "$overlay.dtbo" "$makefile"; then
              continue
            fi
            if [ -n "$patches" ] && grep -q -E -- "^\+.*\<$overlay\.dtbo\>" $patches; then
              continue
            fi
            echo "config.txt names overlay $overlay, which the kernel does not build" >&2
            status=1
          done
          [ "$status" -eq 0 ] && touch "$out"
          exit "$status"
        '';
    };
  };
}
