{
  lib,
  runCommand,
  beagleyArtifact,
  beagleyBuilt,
}: let
  release = import ./release.nix;
  members = map beagleyArtifact ["tifs-enc" "tifs-cert" "dm-firmware"];
in
  beagleyBuilt "boot-firmware" (runCommand "beagley-ai-boot-firmware-${release.firmware.version}" {
      passthru = {
        provenance = release.sources.firmware;
        inherit (release.firmware) publicationPolicy;
      };
      meta = {
        description = "Reviewed J722S HS-FS TIFS and system Device Manager firmware";
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      ${lib.concatMapStringsSep "\n" (member: ''
          install -Dm444 ${member}/${member.manifestEntry.path} "$out/${member.manifestEntry.path}"
        '')
        members}
      mkdir -p "$out/share/licenses/beagley-ai-boot-firmware"
      cp ${lib.head members}/share/licenses/*/* "$out/share/licenses/beagley-ai-boot-firmware/"
    '')
