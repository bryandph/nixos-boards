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
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    nixosCfg = config.flake.nixosConfigurations.uconsole-free.config;
    kernel = nixosCfg.boot.kernelPackages.kernel;
    overlays = lib.unique (lib.concatMap (line: let
      m = builtins.match "dtoverlay=([^,]+).*" line;
    in
      lib.optional (m != null) (lib.head m))
    (lib.splitString "\n" nixosCfg.hardware.raspberry-pi.config-generated));
  in {
    checks =
      {
        # The speaker switch against mocked GPIO tools: it must follow every
        # headphone transition and release the line on shutdown.
        uconsole-audio-switch = let
          mockGpio = pkgs.writeShellScriptBin "gpioget" ''
            n=$(cat "$MOCK/polls" 2>/dev/null || echo 0)
            echo $((n + 1)) > "$MOCK/polls"
            sed -n "$((n + 1))p" "$MOCK/hp" | grep . || tail -n 1 "$MOCK/hp"
          '';
          mockSet = pkgs.writeShellScriptBin "gpioset" ''
            line=''${*: -1}
            echo $$ >> "$MOCK/holders"
            echo "hold $line" >> "$MOCK/log"
            trap 'echo "release $line" >> "$MOCK/log"; exit 0' TERM
            while true; do sleep 0.05; done
          '';
          switch = pkgs.callPackage ../../../packages/clockworkpi/uconsole/audio-switch.nix {
            libgpiod = pkgs.symlinkJoin {
              name = "mock-libgpiod";
              paths = [mockGpio mockSet];
            };
            pollInterval = "0.1";
          };
        in
          pkgs.runCommand "uconsole-audio-switch" {} ''
            export MOCK=$PWD
            # Polls: none, inserted, removed, then stays removed.
            printf '0\n0\n1\n1\n0\n' > hp
            ${switch}/bin/uconsole-audio-switch &
            pid=$!
            for _ in $(seq 100); do
              [ "$(cat polls 2>/dev/null || echo 0)" -ge 8 ] && break
              sleep 0.1
            done
            kill -TERM "$pid"
            status=0
            for _ in $(seq 50); do
              kill -0 "$pid" 2>/dev/null || break
              sleep 0.1
            done
            if kill -0 "$pid" 2>/dev/null; then
              echo "the switch did not exit on SIGTERM" >&2
              kill -KILL "$pid"
              status=1
            fi
            sleep 0.2
            for holder in $(cat holders); do
              if kill -0 "$holder" 2>/dev/null; then
                echo "gpioset $holder still holds the line after shutdown" >&2
                kill -KILL "$holder"
                status=1
              fi
            done
            cat log
            printf '%s\n' "hold GPIO11=1" "release GPIO11=1" "hold GPIO11=0" "release GPIO11=0" "hold GPIO11=1" "release GPIO11=1" > expected
            diff -u expected log || status=1
            [ "$status" -eq 0 ] && touch "$out"
            exit "$status"
          '';
      }
      # The kernel source is prepared on the board's platform.
      // lib.optionalAttrs (system == config.boards.registry.uconsole.system) {
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
