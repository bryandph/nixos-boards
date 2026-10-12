# FRDM-i.MX95 release manifest (D6) for NXP Linux Factory 6.18.20-2.0.0.
# Every NXP-licensed file is operator-supplied (R2): the NXP Software
# License Agreement permits distribution only as part of an authorized
# NXP-based system (section 2.3), not as standalone files or caches.
# Each file is imported by a board app after the operator accepts NXP's
# license; the store names match the files, so earlier imports are reused.
_: let
  retrieved = "2026-10-12";
  nxpAgreement = "https://www.nxp.com/docs/en/disclaimer/LA_OPT_NXP_Software_License.pdf";
  neutronRev = "d0ff138390aeba2b6c5169d8f0ca13f6a6b8219a";

  licenses = {
    nxp = {
      shortName = "LicenseRef-NXP-Software-License";
      fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
      url = nxpAgreement;
      free = false;
      redistributable = false;
    };
    eiq = {
      shortName = "LicenseRef-NXP-eIQ-Neutron-SDK";
      fullName = "NXP eIQ Neutron SDK license (converted model output)";
      url = "https://eiq.nxp.com/learning-hub/tools/neutronSdk/softwareTools/NeutronConverter.html";
      free = false;
      redistributable = false;
    };
  };

  evidence = {
    agreement = {
      url = nxpAgreement;
      inherit retrieved;
      location = "§2.2(a): use and reproduce solely for developing an Authorized System, no distribution to others (internal copies only); §2.3: distribution only within an Authorized System; ELE and firmware-imx recipes share COPYING md5 bc649096ad3928ec06a8713b8d787eac; LF6.18.20 Software Content Register";
    };
    neutron = {
      url = "https://github.com/nxp-imx/neutron/blob/${neutronRev}/LICENSE.txt";
      inherit retrieved;
      location = "LICENSE.txt (LA_OPT_NXP_Software_License v63, git blob 37ddcbd5) §2.2(a) internal reproduction only; SW-Content-Register.txt at the pinned revision";
    };
    converter = {
      url = licenses.eiq.url;
      inherit retrieved;
      location = "converter documentation and the eIQ Toolkit download terms: no redistribution grant for the tool or converted payloads (reviewed 2026-07-24)";
    };
  };

  instructions = app: arguments: ''
    NXP's license must be accepted before this file can be used, and it
    cannot be downloaded automatically. Obtain the release-pinned NXP
    distribution, review its license, then run:

      nix run github:bryandph/nixos-boards#${app} -- --accept-license ${arguments}

    The app verifies the distribution and adds only the pinned files to the
    local Nix store. See the FRDM-i.MX95 firmware page.
  '';
  firmwareImport = instructions "frdm-imx95-import-nxp-firmware" "<firmware-ele-imx-2.0.6-c0b284c.bin> <firmware-imx-8.32-1991416.bin>";

  operatorSupplied = {
    file,
    size,
    sha256,
    layer,
    load,
    features,
    how,
    license ? licenses.nxp,
    evidenceFor ? evidence.agreement,
  }: {
    class = "R2";
    path = file;
    inherit size sha256 layer load features license;
    evidence = evidenceFor;
    instructions = how;
    # NXP SLA §2.2(a) permits the licensee to reproduce the software for
    # developing an Authorized System, but not to distribute it to others:
    # internal build and private-cache copies only, never public forms.
    redistribution.private = license == licenses.nxp;
  };
  bootFirmware = file: size: sha256:
    operatorSupplied {
      inherit file size sha256;
      layer = "boot-firmware";
      load = "boot-image";
      features = ["frdm-imx95-boot-container"];
      how = firmwareImport;
    };
  neutronMember = file: size: sha256:
    operatorSupplied {
      inherit file size sha256;
      layer = "runtime-firmware";
      load =
        if file == "NeutronFirmware.elf"
        then "firmware"
        else "userspace";
      features = ["frdm-imx95-neutron-npu"];
      evidenceFor = evidence.neutron;
      how = ''
        Check out https://github.com/nxp-imx/neutron at ${neutronRev},
        review its LICENSE.txt, then run:

          nix run github:bryandph/nixos-boards#frdm-imx95-import-neutron-runtime -- --accept-license <checkout>
      '';
    };

  built = attrs:
    {
      class = "R2";
      license = licenses.nxp;
      evidence = evidence.agreement;
      redistribution.private = (attrs.license or licenses.nxp) == licenses.nxp;
    }
    // attrs;
in {
  inherit licenses;
  manifest = {
    provider = "nxp-lf-6.18.20-2.0.0";
    version = "6.18.20-2.0.0";
    source = "NXP Linux Factory 6.18.20-2.0.0 for the FRDM-i.MX95 (meta-imx wrynose-6.18.20-2.0.0)";
    artifacts = {
      ele-firmware = bootFirmware "mx95b0-ahab-container.img" 175488 "sha256-Q7qtB9CHiekabZVvUHElf7RoC+X7z+yirwoz/1AJ9Tw=";
      lpddr4x-dmem = bootFirmware "lpddr4x_dmem_v202409.bin" 65536 "sha256-HncNPw8Nn9ekvn2Km6adtgoSOQiPPy6jjBlEVky4nWs=";
      lpddr4x-dmem-qb = bootFirmware "lpddr4x_dmem_qb_v202409.bin" 65536 "sha256-uTRKp6ZMffalNzFdu6/E3EuEuwpz/qenmMBZ18HSNqw=";
      lpddr4x-imem = bootFirmware "lpddr4x_imem_v202409.bin" 51860 "sha256-hiW9S9+szfdzRpp/gdiuJw56fsSkUcv0uQ+LvE3COYo=";
      lpddr4x-imem-qb = bootFirmware "lpddr4x_imem_qb_v202409.bin" 25224 "sha256-k5RuLtQUiJwKtHiZwgGDO8GAfLNn5eMTChHAvB9Y7bU=";
      wave6-distribution = operatorSupplied {
        file = "firmware-imx-8.32-1991416.bin";
        size = 2033181;
        sha256 = "sha256-ETluV5i2LNYZY9uAbAwFUAiHvGKpjh0W28MBSqDCGio=";
        layer = "runtime-firmware";
        load = "firmware";
        features = ["frdm-imx95-wave6-vpu"];
        how = instructions "frdm-imx95-import-nxp-wave6-firmware" "<firmware-imx-8.32-1991416.bin>";
      };
      m7-power-mode-demo = operatorSupplied {
        file = "imx95-15x15-frdm_m7_TCM_power_mode_switch.bin";
        size = 35916;
        sha256 = "sha256-FRQbpcZlBBMbRcXa8p8s8adSc8/48Y8MwgWqOk1Xzbk=";
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["frdm-imx95-m7-remoteproc"];
        how = instructions "frdm-imx95-import-nxp-m7-power-mode-demo" "<LF_v6.18.20-2.0.0_images_IMX95EVK.zip>";
      };
      complete-boot-container = operatorSupplied {
        file = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all";
        size = 2976768;
        sha256 = "sha256-cIRAg/mrMAqqJawvRW/kK/FZdCsVtPuGvaRTDeZyhSk=";
        layer = "boot-firmware";
        load = "boot-image";
        features = ["frdm-imx95-boot-container"];
        how = ''
          The complete NXP container is used only for compatibility and
          recovery. Download LF_v6.18.20-2.0.0_images_IMX95EVK.zip after
          accepting NXP's license, then run:

            nix run github:bryandph/nixos-boards#frdm-imx95-import-nxp-boot-container -- <LF_v6.18.20-2.0.0_images_IMX95EVK.zip>
        '';
      };
      neutron-firmware = neutronMember "NeutronFirmware.elf" 46388 "sha256-+hBYhYPQsQw63LZd5LZIg+kieWc3rzKEaHtij8+Ev04=";
      neutron-driver = neutronMember "libNeutronDriver.so" 68496 "sha256-7MvFRNg8632NI4bsR+/A1oSIx25l3vuNCTHTz8eauMM=";
      neutron-driver-header = neutronMember "NeutronDriver.h" 8880 "sha256-fOxThBIQaJIsRaLbB/FIO8CuKlVtGDHA+uGHVcHCsUw=";
      neutron-errors-header = neutronMember "NeutronErrors.h" 2693 "sha256-OOtdNYE1KrOnr1pWXX4XsVImEc9GinY6lz8ZHAg4FjY=";
      # Publicly downloadable, but NXP grants no redistribution.
      eiq-neutron-sdk-wheel =
        operatorSupplied {
          file = "eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl";
          size = 140347196;
          sha256 = "sha256-rfZONNEWKSA4Mh3RSn44FToZH5FYUN5qFDNzBCk4eP4=";
          layer = "userspace";
          load = "userspace";
          features = ["frdm-imx95-neutron-npu"];
          license = licenses.eiq;
          evidenceFor = evidence.converter;
          how = ''
            Review the eIQ Neutron SDK terms, then run:

              nix run github:bryandph/nixos-boards#frdm-imx95-import-artifacts -- --accept-license
          '';
        }
        // {url = "https://eiq.nxp.com/repository/eiq-neutron-sdk/eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl";};
      neutron-converted-model = operatorSupplied {
        file = "mobilenet_v1_1.0_224_quant-neutron.tflite";
        size = 4334416;
        sha256 = "sha256-lGqRL2ix2Nhc4zkRKHzcPu2vTNvRsQLXugwSXGWg6bo=";
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
        license = licenses.eiq;
        evidenceFor = evidence.converter;
        how = ''
          Convert MobileNet v1 with NXP's eIQ Neutron SDK 3.1.2 after
          accepting its license, on x86_64-linux:

            nix run github:bryandph/nixos-boards#frdm-imx95-convert-neutron-model -- --accept-license <eiq-neutron-sdk wheel> <neutron-converter> <mobilenet_v1_1.0_224_quant.tflite> 946a912f68b1d8d85ce33911287cdc3eedaf4cdbd1b102d7ba0c125c65a0e9ba
        '';
      };
    };

    built = {
      source-boot-container = built {
        from = ["ele-firmware" "lpddr4x-dmem" "lpddr4x-dmem-qb" "lpddr4x-imem" "lpddr4x-imem-qb"];
        sources = ["NXP U-Boot (GPL-2.0-or-later)" "imx-atf (BSD-3-Clause)" "imx-optee-os (BSD-2-Clause)" "imx-sm (BSD-3-Clause)" "imx-oei (BSD-3-Clause)" "imx-mkimage (GPL-2.0-only)"];
        layer = "boot-firmware";
        load = "boot-image";
        features = ["frdm-imx95-boot-container" "frdm-imx95-m7-remoteproc"];
      };
      complete-boot-container-provider = built {
        from = ["complete-boot-container"];
        layer = "boot-firmware";
        load = "boot-image";
        features = ["frdm-imx95-boot-container"];
      };
      wave6-firmware = built {
        from = ["wave6-distribution"];
        layer = "runtime-firmware";
        load = "firmware";
        features = ["frdm-imx95-wave6-vpu"];
      };
      m7-power-mode-demo-firmware = built {
        from = ["m7-power-mode-demo"];
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["frdm-imx95-m7-remoteproc"];
      };
      neutron-runtime = built {
        from = ["neutron-firmware" "neutron-driver" "neutron-driver-header" "neutron-errors-header"];
        evidence = evidence.neutron;
        layer = "runtime-firmware";
        load = "firmware";
        features = ["frdm-imx95-neutron-npu"];
      };
      tflite-neutron-delegate = built {
        from = ["neutron-driver" "neutron-driver-header" "neutron-errors-header"];
        sources = ["nxp-imx/tflite-neutron-delegate and tensorflow-imx (Apache-2.0)"];
        evidence = evidence.neutron;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
      eiq-neutron-sdk = built {
        from = ["eiq-neutron-sdk-wheel"];
        license = licenses.eiq;
        evidence = evidence.converter;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
      neutron-model = built {
        from = ["neutron-converted-model"];
        license = licenses.eiq;
        evidence = evidence.converter;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
      neutron-smoke = built {
        from = ["neutron-driver" "neutron-converted-model"];
        # The converted model's eIQ terms grant no internal copies.
        redistribution.private = false;
        evidence = evidence.neutron;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
    };
  };
}
