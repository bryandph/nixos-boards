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
        uconsole-security-contract = assert !nixosCfg.services.gpsd.listenany;
        assert lib.hasInfix ''GROUP="dialout", MODE="0660"'' nixosCfg.services.udev.extraRules;
        assert !(lib.hasInfix ''MODE="0666"'' nixosCfg.services.udev.extraRules);
        assert builtins.elem "dialout" nixosCfg.systemd.services.gpsd.serviceConfig.SupplementaryGroups;
        assert lib.all (resource: lib.any (claim: claim.resource == resource && claim.owner == "uconsole-core") nixosCfg.hardware.boards.claims) ["gpio:2" "gpio:3" "gpio:8" "gpio:9" "gpio:10" "gpio:11" "gpio:12" "gpio:13"];
          pkgs.writeText "uconsole-security-contract" "GPS defaults local-only/group access and core overlay GPIO claims evaluated; no hardware acceptance.\n";
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
      // {
        # Panel detection from the CWU50 patch, compiled against stub DSI
        # calls: only a successful read may select the v2/v3 sequence.
        uconsole-panel-detect = let
          patch = ../../../packages/clockworkpi/uconsole/patches/0001-drm-panel-add-clockworkpi-cwu50.patch;
          harness = pkgs.writeText "panel-detect-harness.c" ''
            #include <assert.h>
            #include <stdbool.h>
            #include <stdio.h>
            #include <string.h>
            #include <sys/types.h>
            typedef unsigned char u8;
            struct device { int unused; };
            struct mipi_dsi_device { int unused; };
            struct cwu50 { struct device *dev; bool is_new_panel; };
            static ssize_t read_ret;
            static u8 read_bytes[3];
            static int warnings;
            /* Writes the bytes even on failure, standing in for stale memory. */
            static ssize_t mipi_dsi_dcs_read(struct mipi_dsi_device *dsi, u8 cmd, void *buf, size_t len)
            {
              (void)dsi; assert(cmd == 0x04 && len == 3);
              memcpy(buf, read_bytes, len);
              return read_ret;
            }
            #define dev_warn(dev, ...) (warnings++)
            #include "detect.c"
            static bool run(bool start, ssize_t ret, u8 first)
            {
              struct device dev; struct mipi_dsi_device dsi;
              struct cwu50 ctx = { &dev, start };
              read_ret = ret; read_bytes[0] = first;
              cwu50_detect_panel(&ctx, &dsi);
              return ctx.is_new_panel;
            }
            int main(void)
            {
              assert(!run(false, -5, 0x39));  /* failed read ignores the buffer */
              assert(!run(false, 0, 0x39));   /* empty read ignores the buffer */
              assert(run(true, -5, 0x00));    /* failure keeps an earlier v2/v3 choice */
              assert(run(false, 1, 0x39));    /* v2/v3 panel */
              assert(!run(false, 3, 0x00));   /* old panel */
              assert(warnings == 3);
              puts("panel detection OK");
              return 0;
            }
          '';
        in
          pkgs.runCommandCC "uconsole-panel-detect" {} ''
            awk '/^\+static void cwu50_detect_panel\(/ {on = 1} on {print substr($0, 2)} on && /^\+}$/ {exit}' ${patch} > detect.c
            grep -q 'cwu50_detect_panel' detect.c
            cp ${harness} harness.c
            $CC -Wall -Werror -o harness harness.c
            ./harness
            touch $out
          '';
      }
      // {
        # power_supply_put_battery_info() frees the battery info, so the AXP20x
        # probe must not read it afterwards. Checks the patch's new side.
        uconsole-battery-info-lifetime = pkgs.runCommand "uconsole-battery-info-lifetime" {} ''
          awk '
            /^diff --git/ { file = ($0 ~ /axp20x_battery\.c/) }
            file && /^[ +]/ {
              line = substr($0, 2)
              if (line ~ /power_supply_put_battery_info\(/) { freed = 1; next }
              if (freed && line ~ /info->/) { print "info used after put: " line; bad = 1 }
              if (freed && line ~ /^\t}/) freed = 0
            }
            END { exit bad }
          ' ${../../../packages/clockworkpi/uconsole/patches/0004-power-axp20x-clockworkpi-uconsole.patch}
          touch $out
        '';
      }
      # The kernel source is prepared on the board's platform.
      // lib.optionalAttrs (system == config.boards.registry.uconsole.system) {
        # Compiles only the patched CWU50 panel and AXP20x battery drivers in
        # the board kernel's configured tree, without building the kernel.
        uconsole-patched-drivers = kernel.overrideAttrs (_: {
          pname = "uconsole-patched-drivers";
          buildFlags = [
            "drivers/gpu/drm/panel/panel-cwu50.o"
            "drivers/power/supply/axp20x_battery.o"
          ];
          installPhase = ''
            # Structured attrs: outputs is an associative array.
            for o in "''${!outputs[@]}"; do mkdir -p "''${outputs[$o]}"; done
            test -s "$buildRoot/drivers/gpu/drm/panel/panel-cwu50.o"
            test -s "$buildRoot/drivers/power/supply/axp20x_battery.o"
          '';
          postInstall = "";
          dontFixup = true;
          doCheck = false;
          requiredSystemFeatures = [];
        });
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
