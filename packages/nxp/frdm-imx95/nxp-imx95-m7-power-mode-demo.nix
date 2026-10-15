{
  lib,
  runCommand,
  frdmArtifact,
  frdmBuilt,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  demo = release.licensedFirmware.m7PowerModeDemo;
  distribution = demo.distribution;
  member = demo.member;
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
      url = "https://www.nxp.com/docs/en/disclaimer/LA_OPT_NXP_Software_License.pdf";
      redistributable = false;
    };
  src = let
    artifact = frdmArtifact "m7-power-mode-demo";
  in "${artifact}/${artifact.manifestEntry.path}";
in
  frdmBuilt "m7-power-mode-demo-firmware" (runCommand "frdm-imx95-m7-power-mode-demo-firmware-${release.release.version}" {
      inherit src;

      allowSubstitutes = false;
      preferLocalBuild = true;

      passthru = {
        inherit distribution member;
        expectedSha256 = member.sha256;
        expectedSize = member.size;
        fileName = member.fileName;
        firmwareFormat = release.m7.remoteproc.vendorDemoFormat;
        providerLicense = nxpLicense;
        release = release.release.version;
        remoteprocLoadable = false;
      };

      meta = {
        description = "Operator-supplied NXP FRDM-i.MX95 M7 power-mode compatibility firmware";
        homepage = nxpLicense.url;
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      actualSize=$(stat -c %s "$src")
      if [ "$actualSize" -ne ${toString member.size} ]; then
        echo "${member.fileName} has size $actualSize; expected ${toString member.size}" >&2
        exit 1
      fi

      actualSha256=$(sha256sum "$src" | cut -d' ' -f1)
      if [ "$actualSha256" != ${lib.escapeShellArg member.sha256} ]; then
        echo "${member.fileName} failed its pinned SHA-256 check" >&2
        exit 1
      fi

      install -Dm0444 "$src" "$out/share/nxp-imx95-compatibility/${member.fileName}"
    '')
