# BeagleY-AI release manifest (D6) for the BeagleBoard 6.12 kernel and TI
# Processor SDK 11.02. Every non-free input is an artifact or a built
# package; the licensing review is recorded on LAB-148.
{}: let
  tiFirmwareRev = "d528873a75e532075a1fd5d2a53defef98d60437";
  tiFirmware = path: "https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/plain/${path}?id=${tiFirmwareRev}";
  sandboxRev = "be3a57d2760691f6b4f5cc7cae6e00ccddef7016";
  sandbox = path: "https://raw.githubusercontent.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/${sandboxRev}/${path}";
  retrieved = "2026-10-12";

  licenses = {
    tiText = {
      shortName = "LicenseRef-TI-Text-File";
      fullName = "TI Text File License (unmodified binaries and TI-device source; use only with TI devices)";
      url = tiFirmware "LICENSE.ti";
      free = false;
      redistributable = true;
    };
    tiConnectivity = {
      shortName = "LicenseRef-TI-connectivity";
      fullName = "TI limited license for connectivity firmware (unmodified binaries; use only with TI devices)";
      url = "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/20250808/LICENCE.ti-connectivity";
      free = false;
      redistributable = true;
    };
    chipsMedia = {
      shortName = "LicenseRef-Chips-Media-firmware";
      fullName = "Chips&Media firmware license (unmodified binaries; TI silicon only)";
      url = tiFirmware "LICENCE.cnm";
      free = false;
      redistributable = true;
    };
    modelzoo = {
      shortName = "LicenseRef-TI-edgeai-modelzoo";
      fullName = "TI edgeai-modelzoo (BSD-3-Clause), with facebookresearch/pycls models (MIT)";
      url = "https://github.com/TexasInstruments/edgeai-modelzoo/blob/main/LICENSE.md";
      free = true;
      redistributable = true;
    };
    noGrant = {
      shortName = "LicenseRef-no-redistribution-grant";
      fullName = "No independently established redistribution grant for the helper or affected output; internal TI-target use is an operator-accepted interpretation";
      free = false;
      redistributable = false;
    };
  };

  notices = {
    tiText = {
      url = tiFirmware "LICENSE.ti";
      sha256 = "sha256-qyD/vnu6fpS+JGs0F9M6kUs/B8FsR+9af3YCNJpmamE=";
    };
    whence = {
      url = tiFirmware "WHENCE";
      sha256 = "sha256-QS2K5Ky58yga+5MT7j89xhAK6/5CpsIRSdEKPSgEiwM=";
    };
    chipsMedia = {
      url = tiFirmware "LICENCE.cnm";
      sha256 = "sha256-iCNtWuRberyWwqtMaVKviHWOJLF0Et0XN0buHFWbPG8=";
    };
    tiConnectivity = {
      url = licenses.tiConnectivity.url;
      sha256 = "sha256-GQ/fEDJ4zWn0idwNHU2oHZo2r4tbrqM2Vn/LHfUaGXM=";
    };
    rogue = {
      url = "https://raw.githubusercontent.com/TexasInstruments/ti-img-rogue-umlibs/adcbb5c620ff172da4152c02a2fee8f42dc4c472/LICENSE";
      sha256 = "sha256-N1B7Ri7fl7WXF9LRRNqqyF+8pggMNgK1Eo5Ebpf5rUc=";
    };
    # The upstream notices for files that carry none of their own.
    tidlTools = {
      url = "https://raw.githubusercontent.com/TexasInstruments/edgeai-tidl-tools/84a10915e27dfb76a11c27e879fc5adc50793538/LICENSE";
      sha256 = "sha256-PGucKgcuysRNRh9etfqFSsuA3TS7oD1UE9X1TpzMfKM=";
    };
    modelzoo = {
      url = "https://raw.githubusercontent.com/TexasInstruments/edgeai-modelzoo/99f1bd6e434bdde9d26c3b0678ce368e69050ea3/LICENSE.md";
      sha256 = "sha256-yjCiS+PtJw/gFVRm82X3IOB/zeYNnG19rdnUPIri2GM=";
    };
    # MIT requires its notice in all copies, including internal ones.
    pycls = {
      url = "https://raw.githubusercontent.com/facebookresearch/pycls/5719de641657c251f807c20a1fcf8ef6f4b60144/LICENSE";
      sha256 = "sha256-UkEte8fOQVfqYou6rLiCngqcs8WPV/mRdhJryM8r/IU=";
    };
  };

  evidence = {
    tiFirmware = {
      url = tiFirmware "LICENSE.ti";
      inherit retrieved;
      location = "LICENSE.ti, Limited License: binary redistribution without modification";
    };
    chipsMedia = {
      url = tiFirmware "LICENCE.cnm";
      inherit retrieved;
      location = "LICENCE.cnm, clauses 1 and 2.1";
    };
    tiConnectivity = {
      url = "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/20250808/LICENCE.ti-connectivity";
      inherit retrieved;
      location = "LICENCE.ti-connectivity, Limited License: binary redistribution without modification";
    };
    rogue = {
      url = notices.rogue.url;
      inherit retrieved;
      location = "LICENSE, TI Text File License: binary redistribution without modification";
    };
    psdk = {
      url = "https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-1bSfTnVt5d/11.02.01.03/ti-processor-sdk-rtos-j722s-evm-11_02_01_03.tar.gz";
      inherit retrieved;
      location = "psdk_rtos/PROCESSOR_SDK_RTOS_J722S_manifest.html: TI Text File, BSD, MIT and Apache-2.0 components; the GCC binary is GPL-3.0";
    };
    tools = {
      url = "https://www.ti.com/tool/download/ARM-CGT-CLANG";
      inherit retrieved;
      location = "installer manifests (TI_Arm_Clang_Compiler_4.0.3, C7000_Code_Generation_Tools_C7000-CGT-5, SysConfig_Core_Tool_1.25.0): TI Text File License with open-source runtime parts";
    };
    tiSources = {
      url = "https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-1bSfTnVt5d/11.02.01.03/ti-processor-sdk-rtos-j722s-evm-11_02_01_03.tar.gz";
      inherit retrieved;
      location = "psdk_rtos/PROCESSOR_SDK_RTOS_J722S_manifest.html: vision_apps, tiovx, imaging, app_utils, edgeai components under the TI Text File License";
    };
    sandbox = {
      url = "https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/tree/${sandboxRev}";
      inherit retrieved;
      location = "repository root and patches/: no LICENSE file at the pinned revision";
    };
    tidlTools = {
      url = "https://github.com/TexasInstruments/edgeai-tidl-tools/blob/11_02_16_00/LICENSE";
      retrieved = "2026-10-13";
      location = "The archive embeds no license or notice. TI distributes it through edgeai-tidl-tools 11_02_16_00 (TI Text File License: use, and unmodified binary redistribution for TI devices), whose scripts/setup/setup.sh fetches TIDL_TOOLS/<SOC>/tidl_tools from this release tree. Internal copies only until the archive carries its notices";
    };
    model = {
      url = "https://github.com/TexasInstruments/edgeai-modelzoo/blob/main/LICENSE.md";
      retrieved = "2026-10-13";
      location = "The archive embeds no license or notice; its config.yaml names the source model edgeai-modelzoo models/vision/classification/imagenet1k/fbr-pycls/regnetx-200mf.onnx. LICENSE.md: BSD-3-Clause for the modelzoo, and \"The models under the folder fbr-pycls are from facebookresearch/pycls\" under MIT. Internal copies only until the archive carries its notices";
    };
    tidlRuntime = {
      url = "https://github.com/TexasInstruments/edgeai-tidl-tools/blob/11_02_16_00/LICENSE";
      retrieved = "2026-10-13";
      location = "The wheel's METADATA has no License field or license file. TI distributes it through edgeai-tidl-tools 11_02_16_00 (TI Text File License), whose setup scripts install tidlruntime wheels from this release's OSRT_TOOLS tree. Internal copies only until the wheel carries its notices";
    };
  };

  r1Firmware = {
    file = true;
    image = true;
    cache = true;
    private = true;
  };
  r1Image = {
    file = true;
    image = true;
    private = true;
  };
  r1Build = {
    file = true;
    private = true;
  };

  tiFile = {
    path,
    size,
    sha256,
    layer,
    load,
    features,
    noticeFiles ? [notices.tiText notices.whence],
  }: {
    class = "R1";
    url = tiFirmware path;
    inherit path size sha256 layer load features;
    notices = noticeFiles;
    license = licenses.tiText;
    evidence = evidence.tiFirmware;
    redistribution = r1Firmware;
  };
  ipcEcho = file: size: sha256:
    tiFile {
      path = "ti-ipc/j722s/${file}";
      inherit size sha256;
      layer = "runtime-firmware";
      load = "remoteproc";
      features = ["beagley-ai-remoteproc-ipc"];
    }
    // {path = "lib/firmware/ti-ipc/j722s/${file}";};
  cc33xx = name: size: sha256: {
    class = "R1";
    url = "https://raw.githubusercontent.com/beagleboard/repos-arm64/fb0f6eccb2928b6e9d6c0dca5782f45939e85ae4/bbb.io-cc33xx-1.0.2.10-firmware/suite/trixie/debian/${name}";
    path = "lib/firmware/ti-connectivity/${name}";
    inherit size sha256;
    license = licenses.tiConnectivity;
    evidence = evidence.tiConnectivity;
    notices = [notices.tiConnectivity];
    redistribution = r1Firmware;
    layer = "runtime-firmware";
    load = "firmware";
    features = ["beagley-ai-wireless"];
  };
  tool = file: url: size: sha256: {
    class = "R1";
    inherit url size sha256;
    path = "share/beagley-ai/sources/${file}";
    license = licenses.tiText;
    evidence = evidence.tools;
    notices = [notices.tiText];
    redistribution = r1Build;
    layer = "runtime-firmware";
    load = "remoteproc";
    features = ["beagley-ai-vision"];
  };
  operatorSupplied = {
    file,
    url,
    size,
    sha256,
    evidence,
    layer ? "userspace",
    load ? "userspace",
    features,
    license ? licenses.noGrant,
    private ? false,
    noticeFiles ? [],
  }: {
    class = "R2";
    path = "share/beagley-ai/sources/${file}";
    inherit url size sha256 evidence layer load features license;
    notices = noticeFiles;
    redistribution.private = private;
    instructions = ''
      This file carries no license notice of its own, so it is not
      downloaded automatically. Review the source's terms, then run
      `nix run github:bryandph/nixos-boards#beagley-ai-import-artifacts -- --accept-license`
      to download, verify and import it.
    '';
  };

  # Publication/use evidence supports a bounded internal interpretation, not
  # an express license grant to these root-level patches and build helpers.
  sandboxInternalUse = {
    accepted = true;
    target = "Controlled internal builders producing BeagleY-AI J722S TI-device outputs only";
    rationale = "TI's Sandbox organization publishes and uses these pinned helpers in its J722S build/release flow; underlying vision_apps source headers permit modification and source-derived objects for TI devices. Internal use and controlled builder copies are accepted on this bounded evidence.";
    uncertainty = "The package-source Debian Files:* notices do not clearly cover root patches/scripts. An independent grant for the wrapper and explanatory helper text remains inferential. Operator acceptance is not an upstream grant; all affected output caching and standalone helper redistribution remain denied.";
    evidence = {
      url = "https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/tree/${sandboxRev}";
      retrieved = "2026-10-14";
      location = "Published patches/firmware and scripts/compile-j722s-tidl-model.py, scripts/build-edgeai-firmware.sh and packages/edgeai/* build/debian files; vision_apps @86f71a02f1664e9da9096e90ab4d126f5e71cf71 source-header terms. Evidence of intended internal TI-device use, not an explicit independent helper grant.";
    };
  };

  sandboxFile = file: path: size: sha256: features:
    (operatorSupplied {
      inherit file size sha256 features;
      url = sandbox path;
      evidence = evidence.sandbox;
      layer = "runtime-firmware";
      load = "remoteproc";
    })
    // {internalUse = sandboxInternalUse;};

  tiTextBuilt = attrs:
    {
      class = "R1";
      license = licenses.tiText;
      evidence = evidence.tiSources;
      redistribution = r1Image;
      layer = "userspace";
      load = "userspace";
    }
    // attrs;
  operatorBuilt = attrs:
    {
      class = "R2";
      license = licenses.noGrant;
      evidence = evidence.sandbox;
      internalUse = sandboxInternalUse;
      layer = "userspace";
      load = "userspace";
    }
    // attrs;
in {
  inherit licenses;
  manifest = {
    provider = "beagle-ti-6.12-psdk-11.02";
    version = "11.02";
    source = "TI Processor SDK 11.02 for J722S with the BeagleBoard 6.12 kernel, ti-linux-firmware 11.02.15 and the BeagleBoard CC33xx 1.0.2.10 firmware";
    artifacts = {
      tifs-enc = tiFile {
        path = "ti-sysfw/ti-fs-firmware-j722s-hs-fs-enc.bin";
        size = 159744;
        sha256 = "sha256-XpnJtxX1C4udjhfO0GsOGY/suAQNTQ7lUjOtbu7avYc=";
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      tifs-cert = tiFile {
        path = "ti-sysfw/ti-fs-firmware-j722s-hs-fs-cert.bin";
        size = 1684;
        sha256 = "sha256-eOeyAdMJnK7aZ9XmCbkJBo/pjnQT5xJAiFm+psJjUqg=";
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      dm-firmware = tiFile {
        path = "ti-dm/j722s/ipc_echo_testb_mcu1_0_release_strip.xer5f";
        size = 138484;
        sha256 = "sha256-QS4oBaA9IFf1Vw5HMg6B332wSj9uvpHHBEYipfE04JY=";
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      ipc-mcu2-0 = ipcEcho "ipc_echo_test_mcu2_0_release_strip.xer5f" 53524 "sha256-HJ8eBDzP3XkdL/UAVT+NHnssJbWlU+7FbEosshUROxY=";
      ipc-mcu3-0 = ipcEcho "ipc_echo_test_mcu3_0_release_strip.xer5f" 48788 "sha256-UYbykbgpCIT0LwZSN8YwGKO6d1mrycyxgmHe32gW0yQ=";
      ipc-c7x-1 = ipcEcho "ipc_echo_test_c7x_1_release_strip.xe71" 2100544 "sha256-JtzeFi5ZHeqfLfjIQm1Cx7LRHAl5zODM/rtABbODHpg=";
      ipc-c7x-2 = ipcEcho "ipc_echo_test_c7x_2_release_strip.xe71" 2100544 "sha256-I7aELJcVopl2nmBUQRk0gp+gtFekyMNp6gX2j0lywP8=";
      codec-firmware =
        tiFile {
          path = "cnm/wave521c_k3_codec_fw.bin";
          size = 999104;
          sha256 = "sha256-535zpTebk7pa4gj/kUgPgyqJ1H6vHsQsiPa8+Gz/H9g=";
          layer = "runtime-firmware";
          load = "firmware";
          features = ["beagley-ai-multimedia"];
          noticeFiles = [notices.chipsMedia];
        }
        // {
          path = "lib/firmware/cnm/wave521c_k3_codec_fw.bin";
          license = licenses.chipsMedia;
          evidence = evidence.chipsMedia;
        };
      cc33xx-loader = cc33xx "cc33xx_2nd_loader.bin" 70916 "sha256-0JdNAYlpzcYFcuZGAfhDFPGjDqtu8dR2WnGqXOqwF+I=";
      cc33xx-fw = cc33xx "cc33xx_fw.bin" 539500 "sha256-UNCxtxnI6bZS28vkciBPLvQyWVS4+o8xTKskP9w0X3c=";
      cc33xx-conf = cc33xx "cc33xx-conf.bin" 1282 "sha256-IMNNBBaPoUWQeiJ/EC/pYJ+iBTs8GlNVJpnWON/XIn0=";
      rogue-umlibs = {
        class = "R1";
        url = "https://codeload.github.com/TexasInstruments/ti-img-rogue-umlibs/tar.gz/adcbb5c620ff172da4152c02a2fee8f42dc4c472";
        path = "share/beagley-ai/sources/ti-img-rogue-umlibs-adcbb5c620ff172da4152c02a2fee8f42dc4c472.tar.gz";
        size = 157840227;
        sha256 = "sha256-5mgPag92h60Mesy0bocHqk/NEIXiDgOQLMj/mZK8nag=";
        license = licenses.tiText;
        evidence = evidence.rogue;
        notices = [notices.rogue];
        redistribution = r1Image;
        layer = "userspace";
        load = "userspace";
        features = ["beagley-ai-gpu"];
      };
      psdk-rtos = {
        class = "R1";
        url = evidence.psdk.url;
        path = "share/beagley-ai/sources/ti-processor-sdk-rtos-j722s-evm-11_02_01_03.tar.gz";
        size = 2785233113;
        sha256 = "sha256-TH+7DlbufsLCBbR4mIObLzfQn1OeZ6iGataGc05WKqk=";
        license = licenses.tiText;
        evidence = evidence.psdk;
        notices = [notices.tiText];
        redistribution = r1Build;
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["beagley-ai-vision" "beagley-ai-accelerator-runtime"];
      };
      armllvm-installer =
        tool "ti_cgt_armllvm_4.0.4.LTS_linux-x64_installer.bin"
        "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-ayxs93eZNN/4.0.4.LTS/ti_cgt_armllvm_4.0.4.LTS_linux-x64_installer.bin"
        241483092 "sha256-mMYOzCWaB6VL5vzA9VmQMy9JO/5drUYMC6g5Y/XcsG8=";
      c7000-installer =
        tool "ti_cgt_c7000_5.0.0.LTS_linux-x64_installer.bin"
        "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-707zYe3Rik/5.0.0.LTS/ti_cgt_c7000_5.0.0.LTS_linux-x64_installer.bin"
        45498859 "sha256-AGefhScyrSPOqX5vo2SNfC2ayibCREUeiwepHB0g7n8=";
      sysconfig-installer =
        tool "sysconfig-1.26.2_4477-setup.run"
        "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-nsUM6f7Vvb/1.26.2.4477/sysconfig-1.26.2_4477-setup.run"
        174572727 "sha256-mhQq8eq8Ft/1EF0RQWP8LZzfsLITtROdQvmoAoVXfk8=";
      memory-map-patch =
        sandboxFile "j722s-4gb-edgeai-memory-map.patch" "patches/firmware/j722s-4gb-edgeai-memory-map.patch"
        9973 "sha256-pSo8D4ZASFBGVWoPTIoGrsG95div66PbffvD+3TjVMQ=" ["beagley-ai-vision" "beagley-ai-accelerator-runtime"];
      disable-cpsw-patch =
        sandboxFile "j722s-edgeai-disable-cpsw.patch" "patches/firmware/j722s-edgeai-disable-cpsw.patch"
        4829 "sha256-PrsykWEuyLxsA4Avl82ErfQKUcdEN/oqj4B80TOFP04=" ["beagley-ai-vision" "beagley-ai-accelerator-runtime"];
      scrub-workaround =
        sandboxFile "j722s-sdk-scrub-workaround.mk" "patches/firmware/j722s-sdk-scrub-workaround.mk"
        323 "sha256-svNOWg+xyuLMO/wA/vAz6a3bWVBWBb9bciDbYfKwKQM=" ["beagley-ai-vision"];
      model-compiler-script =
        sandboxFile "compile-j722s-tidl-model.py" "scripts/compile-j722s-tidl-model.py"
        7169 "sha256-D2NhjLtYPhuVDmMvXc99AOeYtaSgN3XEsQdCSs9AQn8=" ["beagley-ai-regnet-model"];
      tidl-tools = operatorSupplied {
        file = "tidl_tools.tar.gz";
        url = evidence.tidlTools.url;
        size = 33211086;
        sha256 = "sha256-mPuzEX2lh3Kms/oGbX+6OZK50Lsbr9kGaHed8Ui4zYA=";
        evidence = evidence.tidlTools;
        features = ["beagley-ai-regnet-model"];
        license = licenses.tiText;
        private = true;
        noticeFiles = [notices.tidlTools];
      };
      regnet-archive = operatorSupplied {
        file = "cl-6360_onnxrt_imagenet1k_fbr-pycls_regnetx-200mf_onnx.tar.gz";
        url = evidence.model.url;
        size = 13042183;
        sha256 = "sha256-h40GFJYbKQES7KeFxdf01OfDDsd7N4+NtXMvt6JfMS0=";
        evidence = evidence.model;
        features = ["beagley-ai-regnet-model"];
        license = licenses.modelzoo;
        private = true;
        noticeFiles = [notices.modelzoo notices.pycls];
      };
      tidlruntime-wheel = operatorSupplied {
        file = "tidlruntime-0.1.0-cp312-cp312-linux_aarch64.whl";
        url = evidence.tidlRuntime.url;
        size = 251354;
        sha256 = "sha256-OE2CWjYttyQRwQ7MrPu+9dS0h8FZmCoX4niLtyTFpR4=";
        evidence = evidence.tidlRuntime;
        features = ["beagley-ai-accelerator-runtime"];
        license = licenses.tiText;
        private = true;
        noticeFiles = [notices.tidlTools];
      };
    };

    built = {
      boot-firmware = tiTextBuilt {
        from = ["tifs-enc" "tifs-cert" "dm-firmware"];
        evidence = evidence.tiFirmware;
        redistribution = r1Firmware;
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      uboot-r5 = tiTextBuilt {
        from = ["tifs-enc" "tifs-cert" "dm-firmware"];
        sources = ["BeagleBoard U-Boot 2025.07 (GPL-2.0-or-later)"];
        evidence = evidence.tiFirmware;
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      uboot-a53 = tiTextBuilt {
        from = ["tifs-enc" "tifs-cert" "dm-firmware"];
        sources = ["BeagleBoard U-Boot 2025.07 (GPL-2.0-or-later)" "TI TF-A 11.00.09 (BSD-3-Clause)" "OP-TEE 4.6.0 (BSD-2-Clause)"];
        evidence = evidence.tiFirmware;
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      boot-bundle = tiTextBuilt {
        from = ["tifs-enc" "tifs-cert" "dm-firmware"];
        sources = ["U-Boot R5 and A53 stages above"];
        evidence = evidence.tiFirmware;
        layer = "boot-firmware";
        load = "boot-image";
        features = ["beagley-ai-boot-bundle"];
      };
      ipc-firmware = tiTextBuilt {
        from = ["ipc-mcu2-0" "ipc-mcu3-0" "ipc-c7x-1" "ipc-c7x-2"];
        evidence = evidence.tiFirmware;
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["beagley-ai-remoteproc-ipc"];
      };
      wireless-firmware = tiTextBuilt {
        from = ["cc33xx-loader" "cc33xx-fw" "cc33xx-conf"];
        license = licenses.tiConnectivity;
        evidence = evidence.tiConnectivity;
        layer = "runtime-firmware";
        load = "firmware";
        features = ["beagley-ai-wireless"];
      };
      rogue-userspace = tiTextBuilt {
        from = ["rogue-umlibs"];
        evidence = evidence.rogue;
        features = ["beagley-ai-gpu"];
      };
      # Internal builds only. Input constraints remain transitive; no distinction
      # between tool-only and incorporated inputs, and no output cache clearance.
      edgeai-libraries = operatorBuilt {
        from = ["psdk-rtos" "memory-map-patch" "disable-cpsw-patch"];
        sources = ["TI edgeai-tiovx-kernels, edgeai-tiovx-modules, edgeai-apps-utils and imaging (TI Text File License)"];
        features = ["beagley-ai-camera"];
      };
      edgeai-gstreamer = operatorBuilt {
        from = ["psdk-rtos" "memory-map-patch" "disable-cpsw-patch"];
        sources = ["TI edgeai-gst-plugins (TI Text File License)"];
        features = ["beagley-ai-camera"];
      };
      imx219-dcc = operatorBuilt {
        from = ["psdk-rtos" "memory-map-patch" "disable-cpsw-patch"];
        sources = ["TI imaging IMX219 DCC tuning binaries (TI Text File License)"];
        features = ["beagley-ai-camera"];
      };
      accelerator-armllvm = tiTextBuilt {
        from = ["armllvm-installer"];
        evidence = evidence.tools;
        redistribution = r1Build;
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["beagley-ai-vision"];
      };
      accelerator-c7000 = tiTextBuilt {
        from = ["c7000-installer"];
        evidence = evidence.tools;
        redistribution = r1Build;
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["beagley-ai-vision"];
      };
      accelerator-sysconfig = tiTextBuilt {
        from = ["sysconfig-installer"];
        evidence = evidence.tools;
        redistribution = r1Build;
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["beagley-ai-vision"];
      };
      accelerator-firmware = operatorBuilt {
        from = ["psdk-rtos" "armllvm-installer" "c7000-installer" "sysconfig-installer" "memory-map-patch" "disable-cpsw-patch" "scrub-workaround"];
        sources = ["TI core-secdev-k3 (BSD-3-Clause)"];
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["beagley-ai-vision"];
      };
      accelerator-runtime = operatorBuilt {
        from = ["psdk-rtos" "memory-map-patch" "disable-cpsw-patch"];
        sources = ["TI vision_apps, tiovx, app_utils, imaging, video_io, ti-perception-toolkit, psdk_include, arm-tidl and concerto (TI Text File License)"];
        features = ["beagley-ai-accelerator-runtime"];
      };
      tidl = operatorBuilt {
        from = ["psdk-rtos" "memory-map-patch" "disable-cpsw-patch"];
        sources = ["TI arm-tidl and concerto (TI Text File License)" "TI onnxruntime fork (MIT)" "TI tensorflow fork (Apache-2.0)" "protobuf (BSD-3-Clause)"];
        features = ["beagley-ai-accelerator-runtime"];
      };
      osrt = operatorBuilt {
        from = ["tidlruntime-wheel" "psdk-rtos" "memory-map-patch" "disable-cpsw-patch"];
        sources = ["TI onnxruntime-tidl (MIT), tflite-runtime and tvm (Apache-2.0) wheels"];
        evidence = evidence.tidlRuntime;
        features = ["beagley-ai-accelerator-runtime"];
      };
      model-tools = operatorBuilt {
        from = ["tidl-tools"];
        sources = ["TI x86 onnxruntime-tidl (MIT) and tflite-runtime (Apache-2.0) wheels"];
        license = licenses.tiText;
        internalUse = null; # Established licensed tooling remains unaffected.
        redistribution.private = true;
        evidence = evidence.tidlTools;
        features = ["beagley-ai-regnet-model"];
      };
      regnet-model = operatorBuilt {
        from = ["regnet-archive" "model-compiler-script" "tidl-tools"];
        evidence = evidence.model;
        features = ["beagley-ai-regnet-model"];
      };
    };
  };
}
