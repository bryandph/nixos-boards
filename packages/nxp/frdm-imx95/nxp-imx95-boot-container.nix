{
  lib,
  runCommand,
  frdmArtifact,
  frdmBuilt,
}: let
  pname = "frdm-imx95-complete-boot-container-provider";
  version = "6.18.20-2.0.0";
  fileName = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all";
  expectedSize = 2976768;
  expectedHash = "sha256-cIRAg/mrMAqqJawvRW/kK/FZdCsVtPuGvaRTDeZyhSk=";
  expectedSha256 = "70844083f9ab300aaa25ac2f456fe42bf159742b15b4fb86bda4530de6728529";
  sourceArchiveName = "LF_v6.18.20-2.0.0_images_IMX95EVK.zip";
  sourceArchiveHash = "sha256-dhSboHropC4ypSpGHyHZDIjvRPGm953nt6/oVTah6QM=";
  downloadPage = "https://www.nxp.com/webapp/Download?colCode=L6.18.20-2.0.0_MX95&appType=license";

  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
      url = downloadPage;
      redistributable = false;
    };

  src = let
    artifact = frdmArtifact "complete-boot-container";
  in "${artifact}/${artifact.manifestEntry.path}";
in
  frdmBuilt "complete-boot-container-provider" (runCommand "${pname}-${version}" {
      inherit src;

      allowSubstitutes = false;
      preferLocalBuild = true;

      passthru = {
        inherit
          downloadPage
          expectedHash
          expectedSha256
          expectedSize
          fileName
          sourceArchiveHash
          sourceArchiveName
          ;
        bootContainerOffsetKiB = 32;
        componentManifest = [
          {
            name = "complete-nxp-flash-all-container";
            kind = "licensed-binary";
            sha256 = expectedSha256;
          }
        ];
        containsM7Application = true;
        providerKind = "nxp-complete-container";
        providerLicense = nxpLicense;
        release = version;
        reservedBootRegionMiB = 8;
        ubootEnvironmentOffsetKiB = 7 * 1024;
        ubootEnvironmentSizeBytes = 16 * 1024;
      };

      meta = {
        description = "Licensed NXP AHAB boot container for the FRDM-i.MX95";
        homepage = downloadPage;
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
        sourceProvenance = with lib.sourceTypes; [
          binaryFirmware
          binaryNativeCode
        ];
      };
    } ''
      actualSize=$(stat -c %s "$src")
      if [ "$actualSize" -ne ${toString expectedSize} ]; then
        echo "NXP boot container has size $actualSize; expected ${toString expectedSize}" >&2
        exit 1
      fi

      install -Dm0444 "$src" "$out/${fileName}"
    '')
