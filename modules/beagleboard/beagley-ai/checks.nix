# BeagleY-AI checks. CI runs the flake checks on aarch64-linux; they need no
# operator-supplied (R2) file. Checks that do, or that build the complete
# full-profile system, are hardware checks for operators (board-layout spec).
{
  config,
  lib,
  ...
}: let
  dir = ../../../packages/beagleboard/beagley-ai;
  profiles = config.flake.modules.nixos;
  manifest = config.boards.manifests.beagley-ai;
  # Core, image and boot firmware, with the board's unfree names admitted.
  fixture =
    (config.boards.internal.mkFixtures {
      board = "beagley-ai";
      entry = {
        system = "aarch64-linux";
        free = [profiles.beagley-ai-core profiles.beagley-ai-image profiles.beagley-ai-boot-bundle];
        full = [];
      };
      manifests = [manifest];
    }).full;
  board = fixture.config;
  extend = modules: (fixture.extendModules {inherit modules;}).config;
  extendNamed = names: extend (map (name: profiles.${name}) names);
  failed = c: builtins.any (a: !a.assertion) c.assertions;
  dtb = c: "${c.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb";

  # Expansion headers and the USB gadget.
  routed = extendNamed (map (name: "beagley-ai-header-${name}") ["uart1" "i2c-400khz" "spi0" "pwm12" "mcasp0"]);
  gpio = extendNamed ["beagley-ai-header-gpio14-15"];
  pwm = extendNamed ["beagley-ai-header-pwm14"];
  gadget = extendNamed ["beagley-ai-usb-gadget"];
  gadgetConflict = extend [
    profiles.beagley-ai-usb-gadget
    {
      hardware.boards.claims = [
        {
          resource = "usb:usb0";
          owner = "external-host-owner";
        }
      ];
    }
  ];
  headerConflicts = map extendNamed [
    ["beagley-ai-header-gpio14-15" "beagley-ai-header-uart1"]
    ["beagley-ai-header-uart1" "beagley-ai-header-pwm14"]
    ["beagley-ai-header-pwm12" "beagley-ai-oldi-lcd185"]
  ];

  # Cameras and displays.
  cameras = extendNamed ["beagley-ai-csi0-imx219" "beagley-ai-csi1-imx219"];
  display = extendNamed ["beagley-ai-csi0-imx219" "beagley-ai-dsi-rpi-7inch"];
  mediaConflict = extendNamed ["beagley-ai-csi1-imx219" "beagley-ai-dsi-rpi-7inch"];
  oldi = extendNamed ["beagley-ai-oldi-lcd185" "beagley-ai-dsi-rpi-7inch"];
  oldiConflict = extendNamed ["beagley-ai-oldi-lcd185" "beagley-ai-header-pwm12"];

  # Remote processors: IPC echo (R1) and vision (R2) own them exclusively.
  ipc = extendNamed ["beagley-ai-remoteproc-ipc"];
  vision = extendNamed ["beagley-ai-vision"];
  conflictingOwner = builtins.tryEval (extendNamed ["beagley-ai-remoteproc-ipc" "beagley-ai-vision"]).hardware.beagleyAi.remoteprocOwner;

  # The registry's full fixture.
  fullFixture = config.flake.nixosConfigurations.beagley-ai-full;
  full = fullFixture.config;
  extendFull = names: (fullFixture.extendModules {modules = map (name: profiles.${name}) names;}).config;
  dualCamera = extendFull ["beagley-ai-csi0-imx219" "beagley-ai-csi1-imx219"];
  cameraDisplay = extendFull ["beagley-ai-csi0-imx219" "beagley-ai-dsi-rpi-7inch"];
  packageNames = map lib.getName full.environment.systemPackages;
in {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: let
    packages = config.legacyPackages.beagley-ai;
  in {
    checks = lib.optionalAttrs (system == "aarch64-linux") {
      beagley-ai-sd-identity-guard = pkgs.callPackage (dir + "/sd-identity-check.nix") {};
      beagley-ai-core-composition = assert !(failed board);
      assert builtins.attrNames board.fileSystems == ["/" "/boot"];
      assert !board.services.openssh.enable;
      assert board.boot.loader.generic-extlinux-compatible.configurationLimit >= 2;
        pkgs.runCommand "beagley-ai-core-composition" {} ''
          mkdir "$out"
          cat > "$out/composition.json" <<'EOF'
          ${builtins.toJSON {
            dtb = board.hardware.deviceTree.name;
            kernel = board.boot.kernelPackages.kernel.version;
            filesystems = builtins.attrNames board.fileSystems;
            console = board.boot.kernelParams;
          }}
          EOF
        '';
      beagley-ai-device-tree = board.system.build.beagleyAiDeviceTreeCheck;
      beagley-ai-sd-image-layout = board.system.build.beagleyAiSdImageCheck;
      beagley-ai-boot-reproducibility = let
        r5 = packages.uboot-r5;
        a53 = packages.uboot-a53;
        r5Again = r5.overrideAttrs {BEAGLEY_REPRO_INSTANCE = "second";};
        a53Again = a53.overrideAttrs {BEAGLEY_REPRO_INSTANCE = "second";};
      in
        pkgs.runCommand "beagley-ai-boot-reproducibility" {} ''
          cmp ${r5}/tiboot3.bin ${r5Again}/tiboot3.bin
          cmp ${a53}/tispl.bin ${a53Again}/tispl.bin
          cmp ${a53}/u-boot.img ${a53Again}/u-boot.img
          mkdir "$out"
          sha256sum ${r5}/tiboot3.bin ${a53}/tispl.bin ${a53}/u-boot.img > "$out/SHA256SUMS"
        '';
      beagley-ai-boot-structure = let
        bundle = packages.boot-bundle;
      in
        pkgs.runCommand "beagley-ai-boot-structure" {nativeBuildInputs = [pkgs.dtc pkgs.openssl (pkgs.python3.withPackages (p: [p.cryptography]))];} ''
          cd ${bundle}
          sha256sum -c SHA256SUMS
          openssl x509 -inform DER -in tiboot3.bin -noout -subject
          test "$(fdtget -t s tispl.bin /configurations/conf-0 firmware)" = atf
          test "$(fdtget -t s tispl.bin /configurations/conf-0 loadables)" = 'tee dm spl'
          fdtget -t s u-boot.img /configurations/conf-0 firmware
          python3 ${dir + "/boot-artifact-check.py"} ${bundle} ${bundle.components.r5}/.config ${bundle.components.a53}/.config
          mkdir "$out"
          cp SHA256SUMS "$out/"
        '';
      beagley-ai-wireless-firmware = packages.wireless-firmware;
      beagley-ai-accelerator-lifecycle = pkgs.runCommand "beagley-ai-accelerator-lifecycle-guards" {nativeBuildInputs = [pkgs.python3];} ''
        python3 ${dir + "/accelerator-remoteproc-test.py"} ${dir + "/accelerator-remoteproc.py"}
        touch "$out"
      '';
      beagley-ai-expansion-profiles = assert builtins.all failed (headerConflicts ++ [gadgetConflict]);
        pkgs.runCommand "beagley-ai-expansion-profiles" {nativeBuildInputs = [pkgs.dtc];} ''
          mkdir "$out"
          cp ${dtb routed} "$out/routed.dtb"
          cp ${dtb gpio} "$out/gpio.dtb"
          cp ${dtb pwm} "$out/pwm.dtb"
          cp ${dtb gadget} "$out/gadget.dtb"
          for symbol in main_uart1 mcu_spi0 mcasp0 ecap0; do
            node=$(fdtget -t s "$out/routed.dtb" /__symbols__ "$symbol")
            test "$(fdtget -t s "$out/routed.dtb" "$node" status)" = okay
          done
          node=$(fdtget -t s "$out/routed.dtb" /__symbols__ mcu_i2c0)
          test "$(fdtget -t u "$out/routed.dtb" "$node" clock-frequency)" = 400000
          node=$(fdtget -t s "$out/gpio.dtb" /__symbols__ main_uart1)
          test "$(fdtget -t s "$out/gpio.dtb" "$node" status)" = disabled
          node=$(fdtget -t s "$out/gadget.dtb" /__symbols__ usb0)
          test "$(fdtget -t s "$out/gadget.dtb" "$node" dr_mode)" = peripheral
          echo ${gadget.systemd.services.beagley-usb-gadget.serviceConfig.ExecStart} > "$out/gadget-command"
        '';
      beagley-ai-media-profiles = assert failed mediaConflict;
      assert failed oldiConflict;
        pkgs.runCommand "beagley-ai-media-profiles" {nativeBuildInputs = [pkgs.dtc];} ''
          mkdir "$out"
          cp ${dtb cameras} "$out/dual-camera.dtb"
          cp ${dtb display} "$out/camera-and-dsi.dtb"
          cp ${dtb oldi} "$out/oldi-and-dsi.dtb"
          for symbol in imx219_0 imx219_1; do
            node=$(fdtget -t s "$out/dual-camera.dtb" /__symbols__ "$symbol")
            test "$(fdtget -t s "$out/dual-camera.dtb" "$node" compatible)" = sony,imx219
          done
          test "$(fdtget -t s "$out/camera-and-dsi.dtb" /panel0 compatible)" = 'raspberrypi,7inch-dsi simple-panel'
          node=$(fdtget -t s "$out/camera-and-dsi.dtb" /__symbols__ dsi0)
          test "$(fdtget -t s "$out/camera-and-dsi.dtb" "$node" status)" = okay
          test "$(fdtget -t s "$out/oldi-and-dsi.dtb" /lcd compatible)" = 'lincolntech,lcd185-101ct panel-simple'
        '';
      beagley-ai-accelerator-ipc-dt = assert !conflictingOwner.success; ipc.system.build.beagleyAiAcceleratorDeviceTreeCheck;
      beagley-ai-accelerator-dt-negative =
        pkgs.runCommand "beagley-ai-accelerator-dt-negative" {
          nativeBuildInputs = [pkgs.dtc pkgs.python3];
        } ''
          original=${dtb ipc}
          contract=${ipc.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json
          expect_failure() {
            if python3 ${dir + "/accelerator-dt-check.py"} bad.dtb "$contract" - > failure.log 2>&1; then
              echo "Invalid accelerator DT was accepted" >&2
              exit 1
            fi
            grep -q "$1" failure.log
          }
          cp "$original" bad.dtb
          chmod u+w bad.dtb
          fdtput -t x bad.dtb /reserved-memory/r5f-dma-memory@a0000000 reg 0 70000000 0 100000
          expect_failure 'outside RAM'
          cp "$original" bad.dtb
          chmod u+w bad.dtb
          fdtput -t x bad.dtb /reserved-memory/r5f-dma-memory@a0000000 reg 0 a0100000 0 100000
          expect_failure 'reservation overlap'
          cp "$original" bad.dtb
          chmod u+w bad.dtb
          fdtput -d bad.dtb /reserved-memory/r5f-memory@a0100000 no-map
          expect_failure 'Device Manager memory mapped'
          mkdir "$out"
        '';
      # Evaluation only: the full composition and its feature interactions.
      beagley-ai-full-composition = assert full.hardware.beagleyAi.remoteprocOwner == "vision";
      assert full.hardware.graphics.enable;
      assert !(full.systemd.services.beagley-ai-remoteproc.serviceConfig ? ExecStop);
      assert builtins.hasAttr "beagley-ai-bluetooth-init" full.systemd.services;
      assert builtins.all (name: builtins.elem name packageNames) ["beagley-ai-accelerator-runtime" "beagley-ai-tidl" "beagley-ai-osrt" "beagley-ai-camera" "beagley-ai-regnet-model"];
      assert !(failed full);
      assert !(failed dualCamera);
      assert !(failed cameraDisplay);
      assert !(builtins.any (overlay: builtins.elem overlay.name ["beagley-ai-csi0-imx219" "beagley-ai-csi1-imx219" "beagley-ai-dsi-rpi-7inch" "beagley-ai-oldi-lcd185"]) full.hardware.deviceTree.overlays);
        pkgs.writeText "beagley-ai-full-composition" (builtins.unsafeDiscardStringContext full.system.build.toplevel.drvPath);
    };

    # Operator-run: need imported R2 artifacts or build the full system.
    legacyPackages.hardwareChecks.beagley-ai =
      lib.optionalAttrs (system == "aarch64-linux") {
        full-system = full.system.build.toplevel;
        accelerator-vision-dt = vision.system.build.beagleyAiAcceleratorDeviceTreeCheck;
        full-feature-device-trees = pkgs.runCommand "beagley-ai-full-feature-device-trees" {nativeBuildInputs = [pkgs.dtc];} ''
          mkdir "$out"
          cp ${full.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json "$out/default-contract.json"
          cp ${dualCamera.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json "$out/dual-camera-contract.json"
          cp ${cameraDisplay.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json "$out/camera-display-contract.json"
          test -e ${full.system.build.beagleyAiAcceleratorKernelCheck}
          test -e ${full.system.build.beagleyAiWirelessCheck}
          for symbol in imx219_0 imx219_1; do
            node=$(fdtget -t s ${dtb dualCamera} /__symbols__ "$symbol")
            test "$(fdtget -t s ${dtb dualCamera} "$node" compatible)" = sony,imx219
          done
          test "$(fdtget -t s ${dtb cameraDisplay} /panel0 compatible)" = 'raspberrypi,7inch-dsi simple-panel'
        '';
        accelerator-memory-map = let
          runtime = config.legacyPackages.beagley-ai.accelerator-runtime;
          firmware = full.hardware.boards.artifacts;
          visionFirmware = lib.findFirst (p: lib.getName p == "beagley-ai-accelerator-firmware") null firmware;
        in
          pkgs.runCommand "beagley-ai-accelerator-memory-map" {} ''
            cmp ${runtime}/share/beagley-ai/app_mem_map.h ${visionFirmware}/share/beagley-ai/app_mem_map.h
            cmp ${runtime}/share/beagley-ai/k3-j722s-rtos-memory-map.dtsi ${visionFirmware}/share/beagley-ai/k3-j722s-rtos-memory-map.dtsi
            mkdir "$out"
            cp ${runtime}/share/beagley-ai/app_mem_map.h "$out/"
            sha256sum "$out/app_mem_map.h" > "$out/SHA256SUMS"
          '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        accelerator-firmware-contract = pkgs.callPackage (dir + "/accelerator-firmware-check.nix") {
          firmware = packages.accelerator-firmware;
        };
        model-reproducibility = let
          model = packages.regnet-model;
          rebuild = model.overrideAttrs (_: {rebuildMarker = "independent-compilation";});
        in
          pkgs.runCommand "beagley-ai-model-reproducibility" {} ''
            first=${model}/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf
            second=${rebuild}/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf
            diff -r "$first" "$second"
            test -f "$first/artifacts/runtime-contract.json"
            mkdir "$out"
            cp "$first/artifacts/tidl-compiler-info.json" "$first/artifacts/calibration-manifest.json" "$out/"
          '';
      };
  };
}
