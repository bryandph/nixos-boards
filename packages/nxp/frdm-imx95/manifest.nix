# FRDM-i.MX95 release manifest (D6) for NXP Linux Factory 6.18.20-2.0.0.
# Every NXP-licensed file is operator-supplied (R2): the NXP Software
# License Agreement permits distribution only as part of an authorized
# NXP-based system (section 2.3), not as standalone public files or caches.
# Documented licensed internal build/private-cache copies remain separate.
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
    # Output of the eIQ Neutron converter. NXP's agreement has no clause on
    # converter output; see evidence.converterOutput.
    eiqOutput = {
      shortName = "LicenseRef-NXP-eIQ-Neutron-converter-output";
      fullName = "Output of the NXP eIQ Neutron converter (NXP Software License Agreement v63 §2.2, interpreted)";
      url = "https://eiq.nxp.com/learning-hub/tools/neutronSdk/softwareTools/NeutronConverter.html";
      free = false;
      redistributable = false;
    };
  };

  notices = {
    nxp = {
      url = "https://raw.githubusercontent.com/nxp-imx/neutron/${neutronRev}/LICENSE.txt";
      sha256 = "sha256-MAHPhAGMXLENGDpnj27IqSjHl2FroGs5jXypPAd5qqI=";
    };
    neutron = {
      url = "https://raw.githubusercontent.com/nxp-imx/neutron/${neutronRev}/SW-Content-Register.txt";
      sha256 = "sha256-o/0AzFeBQeXLTB3sci7KMWDyIJhrWpE3MGp2X9/EXxE=";
    };
  };

  evidence = {
    agreement = {
      url = nxpAgreement;
      inherit retrieved;
      location = "§2.2(a): use and reproduce solely in combination with an NXP Product to develop an Authorized System, no distribution to others (internal copies only); §2.3: distribution only within an Authorized System; ELE and firmware-imx recipes share COPYING md5 bc649096ad3928ec06a8713b8d787eac; LF6.18.20 Software Content Register";
    };
    neutron = {
      url = "https://github.com/nxp-imx/neutron/blob/${neutronRev}/LICENSE.txt";
      inherit retrieved;
      location = "LICENSE.txt (LA_OPT_NXP_Software_License v63, git blob 37ddcbd5) §2.2(a): reproduction solely in combination with an NXP Product for developing an Authorized System; SW-Content-Register.txt at the pinned revision additionally grants distribution under §2.3. Manifest clearance remains controlled internal/private only, not standalone public distribution.";
    };
    eiqWheel = {
      url = "https://raw.githubusercontent.com/nxp-imx/neutron/${neutronRev}/LICENSE.txt";
      retrieved = "2026-10-13";
      location = "eiq_neutron_sdk-3.1.2.dist-info/licenses/LA_OPT_NXP_Software_License.txt (v63, May 2025; same text as the Neutron repository's LICENSE.txt) and Software-Content-Register.txt: \"Package License: … Standard use - Section 2.2 applies\" (converter, runner and quantization tool §2.2; driver and firmware §2.3). §2.2(a): use and reproduce solely in combination with an NXP Product for developing an Authorized System, no distribution to others";
    };
    converterOutput = {
      url = licenses.eiqOutput.url;
      retrieved = "2026-10-13";
      location = "The converter is licensed under NXP SLA v63 §2.2 (see eiqWheel), which has no clause on converter output; the input is TensorFlow's MobileNet v1. Interpreted as §2.2(a) internal reproduction for an Authorized System: internal build and private-cache copies only, never public. Interpretation approved by the operator on 2026-10-13";
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
    noticeFiles ? [notices.nxp],
  }: {
    class = "R2";
    path = file;
    inherit size sha256 layer load features license;
    evidence = evidenceFor;
    notices = noticeFiles;
    instructions = how;
    # NXP SLA §2.2(a) permits the licensee to reproduce the software for
    # developing an Authorized System solely in combination with an NXP Product,
    # but not to distribute it to others:
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
      noticeFiles = [notices.nxp notices.neutron];
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
      notices =
        [notices.nxp]
        ++ (
          if builtins.any (id: builtins.elem id ["neutron-firmware" "neutron-driver" "neutron-driver-header" "neutron-errors-header"]) (attrs.from or [])
          then [notices.neutron]
          else []
        );
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
      wave6-codec-member = operatorSupplied {
        file = "wave633c_codec_fw.bin";
        size = 524672;
        sha256 = "sha256-J5lghpqOb3NvQZkhdFSZOiyL2tTZNNgjxlANqZ9f5kc=";
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

            nix run github:bryandph/nixos-boards#frdm-imx95-import-nxp-boot-container -- --accept-license <LF_v6.18.20-2.0.0_images_IMX95EVK.zip>
        '';
      };
      neutron-firmware = neutronMember "NeutronFirmware.elf" 46388 "sha256-+hBYhYPQsQw63LZd5LZIg+kieWc3rzKEaHtij8+Ev04=";
      neutron-driver = neutronMember "libNeutronDriver.so" 68496 "sha256-7MvFRNg8632NI4bsR+/A1oSIx25l3vuNCTHTz8eauMM=";
      neutron-driver-header = neutronMember "NeutronDriver.h" 8880 "sha256-fOxThBIQaJIsRaLbB/FIO8CuKlVtGDHA+uGHVcHCsUw=";
      neutron-errors-header = neutronMember "NeutronErrors.h" 2693 "sha256-OOtdNYE1KrOnr1pWXX4XsVImEc9GinY6lz8ZHAg4FjY=";
      # Publicly downloadable; NXP SLA v63 §2.2 grants internal use only.
      eiq-neutron-sdk-wheel =
        operatorSupplied {
          file = "eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl";
          size = 140347196;
          sha256 = "sha256-rfZONNEWKSA4Mh3RSn44FToZH5FYUN5qFDNzBCk4eP4=";
          layer = "userspace";
          load = "userspace";
          features = ["frdm-imx95-neutron-npu"];
          evidenceFor = evidence.eiqWheel;
          how = ''
            Review the eIQ Neutron SDK terms, then run:

              nix run github:bryandph/nixos-boards#frdm-imx95-import-artifacts -- --accept-license
          '';
        }
        // {url = "https://eiq.nxp.com/repository/eiq-neutron-sdk/eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl";};
      neutron-converted-model =
        operatorSupplied {
          file = "mobilenet_v1_1.0_224_quant-neutron.tflite";
          size = 4334416;
          sha256 = "sha256-lGqRL2ix2Nhc4zkRKHzcPu2vTNvRsQLXugwSXGWg6bo=";
          layer = "userspace";
          load = "userspace";
          features = ["frdm-imx95-neutron-npu"];
          license = licenses.eiqOutput;
          evidenceFor = evidence.converterOutput;
          how = ''
            Convert MobileNet v1 with NXP's eIQ Neutron SDK 3.1.2 after
            accepting its license, on x86_64-linux:

              nix run github:bryandph/nixos-boards#frdm-imx95-convert-neutron-model -- --accept-license <eiq-neutron-sdk wheel> <neutron-converter> <mobilenet_v1_1.0_224_quant.tflite> 946a912f68b1d8d85ce33911287cdc3eedaf4cdbd1b102d7ba0c125c65a0e9ba
          '';
        }
        # Private by the operator-approved interpretation in evidence.converterOutput.
        // {redistribution.private = true;};
    };

    built = {
      source-boot-container = built {
        # Historical accepted aggregate hashes, retained as provenance
        # metadata rather than a CI scanner or publication admission rule.
        derivedHashes = [
          "sha256-5s1YjWQg/daHJI2gwb1A7JR539qJWhuqfo8SM821g5g="
          (builtins.convertHash {
            hash = "0dd1b75a176c4135d744d708f8629842599aebc600ab9444e9509ccec82230a4";
            hashAlgo = "sha256";
            toHashFormat = "sri";
          })
        ];
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
        from = ["wave6-codec-member"];
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
        # The pinned 3.1.2 runtime is shared by the reduced Neutron and full
        # LF providers; do not falsely bind this runtime to the LF kernel.
        provider = "any";
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
        evidence = evidence.eiqWheel;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
      neutron-model = built {
        from = ["neutron-converted-model"];
        license = licenses.eiqOutput;
        evidence = evidence.converterOutput;
        redistribution.private = true;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
      neutron-smoke = built {
        from = ["neutron-driver" "neutron-converted-model"];
        evidence = evidence.neutron;
        layer = "userspace";
        load = "userspace";
        features = ["frdm-imx95-neutron-npu"];
      };
    };
  };
}
