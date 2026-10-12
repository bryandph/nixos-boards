{
  coreutils,
  gnutar,
  gzip,
  lib,
  runCommand,
  xz,
  frdmArtifact,
  frdmBuilt,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  firmware = release.multimedia.wave6.firmware;
  distribution = release.licensedFirmware.ddr.distribution;
  downloadUrl = "https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/${distribution.fileName}";
  # The operator accepted NXP's license when importing the distribution;
  # the build only extracts the single release-recipe member from it.
  src = let
    artifact = frdmArtifact "wave6-distribution";
  in "${artifact}/${artifact.manifestEntry.path}";
in
  frdmBuilt "wave6-firmware" (runCommand "frdm-imx95-wave6-firmware-${release.release.version}" {
      inherit src;
      nativeBuildInputs = [
        coreutils
        gnutar
        gzip
        xz
      ];
      allowSubstitutes = false;
      preferLocalBuild = true;
      passthru = {
        inherit distribution;
        selectedMember = firmware.member;
        publicationPolicy = firmware.publicationPolicy;
        releaseMapping = release.multimedia;
      };
      meta = {
        description = "Operator-supplied i.MX95 Wave6 codec firmware";
        homepage = downloadUrl;
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      work_dir=$(mktemp -d)
      trap 'rm -rf -- "$work_dir"' EXIT

      cd "$work_dir"
      sh "$src" --auto-accept --force
      member="$work_dir/${firmware.member.archivePath}"
      test -f "$member"

      install -Dm0444 "$member" \
        "$out/lib/firmware/${firmware.member.installPath}"
      test "$(find "$out" -type f | wc -l)" -eq 1
      if grep -R -a -F -l "$src" "$out"; then
        echo "Wave6 firmware output unexpectedly retained its source distribution" >&2
        exit 1
      fi
    '')
