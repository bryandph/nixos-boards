{lib}: let
  # GitLab HEAD-only metadata verified file hash/size, no binary fetched.
  base = "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/ab23307cfe7f9366c819025ca3e4778299bc2db2";
  blocked = path: features: {
    status = "blocked";
    blockedReason = "licensing";
    class = "R2";
    inherit path features;
    layer = "runtime-firmware";
    load = "firmware";
  };
in {
  provider = "radxa-7.0.11";
  version = "20260916";
  source = "linux-firmware 20260916 (ab23307cfe7f9366c819025ca3e4778299bc2db2); Radxa DTS a50eb5b7; blocked candidates never fetched";
  artifacts = rec {
    # The vendor DTS explicitly selects Lenovo X13s ZAP on this unfused SoC.
    # Catalogue A690 requests a660 SQE/GMU; all have WHENCE Qualcomm grants.
    gpu-sqe =
      adsp
      // {
        path = "lib/firmware/qcom/a660_sqe.fw";
        size = 43292;
        sha256 = "sha256-0iLz/ikO8FFu4OxDCCWWutLfD8vC4LuyaYdiPO+Qz3Y=";
        load = "firmware";
        features = ["dragon-q8b-gpu"];
        evidence = adsp.evidence // {location = "WHENCE Adreno GPU SQE/GMU and Lenovo X13s ZAP; LICENSE.qcom preamble and §§1.1–1.2";};
        instructions = ''
          Personally review/accept LICENSES/LICENSE.qcom and NOTICE.qcom in
          linux-firmware commit ab23307cfe7f9366c819025ca3e4778299bc2db2.
          Only if accepted, obtain qcom/a660_sqe.fw, verify the manifest hash/size,
          then nix-store --add-fixed sha256 a660_sqe.fw. Never auto-accept terms.
        '';
      };
    gpu-gmu =
      gpu-sqe
      // {
        path = "lib/firmware/qcom/a660_gmu.bin";
        size = 55252;
        sha256 = "sha256-isq3tBfZ696Jod6a4eLCYdNS/KsSLjHs1YDOyf4q5ec=";
        instructions = ''
          Personally review/accept LICENSES/LICENSE.qcom and NOTICE.qcom in
          linux-firmware commit ab23307cfe7f9366c819025ca3e4778299bc2db2.
          Only if accepted, obtain qcom/a660_gmu.bin, verify the manifest hash/size,
          then nix-store --add-fixed sha256 a660_gmu.bin. Never auto-accept terms.
        '';
      };
    gpu-zap =
      gpu-sqe
      // {
        path = "lib/firmware/qcom/sc8280xp/LENOVO/21BX/qcdxkmsuc8280.mbn";
        size = 14392;
        sha256 = "sha256-17jMZIwvAgwPt3cLLYRLQGiOmftUHkVRRTMElhGzTVw=";
        instructions = ''
          Personally review/accept LICENSES/LICENSE.qcom and NOTICE.qcom in
          linux-firmware commit ab23307cfe7f9366c819025ca3e4778299bc2db2.
          Only if accepted, obtain qcom/sc8280xp/LENOVO/21BX/qcdxkmsuc8280.mbn,
          verify the manifest hash/size, then nix-store --add-fixed sha256 qcdxkmsuc8280.mbn.
          This runtime GPU ZAP reuse is explicit in Radxa's DTS, not permission
          to reuse Lenovo UEFI or unrelated board firmware. Never auto-accept terms.
        '';
      };
    adsp = {
      class = "R2";
      path = "lib/firmware/qcom/sc8280xp/radxa/dragon-q8b/qcadsp8280.mbn";
      size = 14668364;
      sha256 = "sha256-LvkjzleYZcAGV6y1C3eerhtrrHUSn8+zji0nU+fjLi8=";
      license = lib.licenses.unfree;
      evidence = {
        url = "${base}/LICENSES/LICENSE.qcom";
        retrieved = "2026-10-12";
        location = "WHENCE Radxa Dragon Q8B; agreement preamble (acceptance), §§1.1–1.2 (binary use/copies, Qualcomm-only, license/notices)";
      };
      notices = [
        {
          url = "${base}/LICENSES/LICENSE.qcom";
          sha256 = "sha256-vpBM0oyykrgM22z0EqsNkVnUMWcemHrUM8H2LgmIqbw=";
        }
        {
          url = "${base}/LICENSES/NOTICE.qcom";
          sha256 = "sha256-+kPhuaE7NBoHrcqdvnPQ+QcteWb9/oEcAfDdKHLXMJo=";
        }
      ];
      redistribution.private = true;
      instructions = ''
        Read linux-firmware 20260916 LICENSES/LICENSE.qcom and NOTICE.qcom.
        Decide personally whether to accept those terms. Only if accepted,
        obtain qcom/sc8280xp/radxa/dragon-q8b/qcadsp8280.mbn from commit
        ab23307cfe7f9366c819025ca3e4778299bc2db2 (release 20260916)
        (ADSP.HT.5.6.c2-00037-MAKENA-1), verify the manifest size/hash, and run
        nix-store --add-fixed sha256 qcadsp8280.mbn.
        No script accepts terms or downloads this file on your behalf.
        This imports only the DSP image: audio topology/service metadata are
        separate unresolved dependencies, not enabled by this artifact alone.
      '';
      layer = "runtime-firmware";
      load = "remoteproc";
      features = ["dragon-q8b-adsp"];
    };
    cdsp = blocked "lib/firmware/qcom/sc8280xp/qccdsp8280.mbn" ["dragon-q8b-compute-dsp"];
    qup = blocked "lib/firmware/qcom/sc8280xp/qupv3fw.elf" ["dragon-q8b-qup"];
    video = blocked "lib/firmware/qcom/vpu/vpu20_p4_gen2_s6.mbn" ["dragon-q8b-video"];
    audio-topology = blocked "lib/firmware/qcom/sc8280xp/SC8280XP-Radxa-Dragon-Q8B-tplg.bin" ["dragon-q8b-audio"];
    uefi =
      (blocked "board-storage/uefi" ["dragon-q8b-uefi-update"])
      // {
        layer = "boot-firmware";
        load = "board-storage";
      };
  };
}
