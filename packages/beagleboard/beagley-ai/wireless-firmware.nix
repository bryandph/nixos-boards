{
  lib,
  runCommand,
  python3,
  beagleyArtifact,
  beagleyBuilt,
}: let
  release = import ./wireless-release.nix;
  ids = {
    "cc33xx_2nd_loader.bin" = "cc33xx-loader";
    "cc33xx_fw.bin" = "cc33xx-fw";
    "cc33xx-conf.bin" = "cc33xx-conf";
  };
in
  assert (import ./release.nix).sources.kernel.rev == release.driver.revision;
    beagleyBuilt "wireless-firmware" (runCommand "beagley-ai-wireless-firmware-${release.sdkVersion}" {
        nativeBuildInputs = [python3];
        passthru = {inherit release;};
        meta = {
          description = "Matched CC3301 Wi-Fi/BLE SDK firmware and board configuration";
          sourceProvenance = [lib.sourceTypes.binaryFirmware];
        };
      } ''
        mkdir -p "$out/share/licenses/beagley-ai-wireless-firmware"
        ${lib.concatMapStringsSep "\n" (member: let
            artifact = beagleyArtifact ids.${member.name};
          in ''
            install -Dm444 ${artifact}/${artifact.manifestEntry.path} "$out/lib/firmware/ti-connectivity/${member.name}"
            cp -n ${artifact}/share/licenses/*/* "$out/share/licenses/beagley-ai-wireless-firmware/"
          '')
          release.members}
        python3 - "$out/lib/firmware/ti-connectivity/cc33xx-conf.bin" <<'PY'
        import pathlib, struct, sys
        data = pathlib.Path(sys.argv[1]).read_bytes()
        assert len(data) == ${toString release.driver.configSize}
        assert struct.unpack_from('<I4H', data) == (${toString release.driver.configMagic}, ${lib.concatMapStringsSep ", " toString release.driver.configVersion})
        assert data[${toString release.driver.bleEnableOffset}] == 1
        assert struct.unpack_from('<I', data, ${toString release.driver.baudOffset})[0] == ${toString release.driver.baudRate}
        assert data[${toString release.driver.flowControlOffset}] == 1
        PY
      '')
