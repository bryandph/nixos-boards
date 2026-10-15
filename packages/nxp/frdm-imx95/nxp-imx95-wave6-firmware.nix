{
  lib,
  runCommand,
  frdmArtifact,
  frdmBuilt,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  firmware = release.multimedia.wave6.firmware;
  distribution = release.licensedFirmware.ddr.distribution;
  artifact = frdmArtifact "wave6-codec-member";
  # Extraction and license acceptance belong exclusively to the operator
  # import app. Builders receive only the pinned requireFile member.
  src = "${artifact}/${artifact.manifestEntry.path}";
in
  frdmBuilt "wave6-firmware" (runCommand "frdm-imx95-wave6-firmware-${release.release.version}" {
      inherit src;
      allowSubstitutes = false;
      preferLocalBuild = true;
      passthru = {
        inherit distribution;
        selectedMember = firmware.member;
        publicationPolicy = firmware.publicationPolicy;
        releaseMapping = release.multimedia;
      };
      meta = {
        description = "Operator-extracted pinned i.MX95 Wave6 codec firmware";
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      install -Dm0444 "$src" "$out/lib/firmware/${firmware.member.installPath}"
      cmp "$src" "$out/lib/firmware/${firmware.member.installPath}"
    '')
