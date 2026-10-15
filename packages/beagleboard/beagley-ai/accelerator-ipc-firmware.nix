{
  lib,
  runCommand,
  beagleyArtifact,
  beagleyBuilt,
}: let
  release = import ./accelerator-ipc-release.nix;
  ids = {
    "ipc_echo_test_mcu2_0_release_strip.xer5f" = "ipc-mcu2-0";
    "ipc_echo_test_mcu3_0_release_strip.xer5f" = "ipc-mcu3-0";
    "ipc_echo_test_c7x_1_release_strip.xe71" = "ipc-c7x-1";
    "ipc_echo_test_c7x_2_release_strip.xe71" = "ipc-c7x-2";
  };
in
  beagleyBuilt "ipc-firmware" (runCommand "beagley-ai-ipc-firmware-${release.version}" {
      meta = {
        description = "Narrow J722S application-core IPC echo firmware, excluding Device Manager";
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      mkdir -p "$out/lib/firmware/ti-ipc/j722s" "$out/share/licenses/beagley-ai-ipc-firmware"
      ${lib.concatMapStringsSep "\n" (member: let
          artifact = beagleyArtifact ids.${member.file};
        in ''
          install -m444 ${artifact}/${artifact.manifestEntry.path} "$out/lib/firmware/ti-ipc/j722s/${member.file}"
          ln -s "ti-ipc/j722s/${member.file}" "$out/lib/firmware/${member.alias}"
          cp -n ${artifact}/share/licenses/*/* "$out/share/licenses/beagley-ai-ipc-firmware/"
        '')
        release.members}
    '')
