# Every FRDM-i.MX95 feature on the combined NXP LF kernel: boot container,
# audio, open GPU and JPEG, M7 remoteproc, Neutron NPU, NVMe and Wave6.
# Needs the operator-imported NXP files (R2).
{config, ...}: {
  flake.modules.nixos.frdm-imx95-full = {
    imports = with config.flake.modules.nixos; [
      frdm-imx95-boot-container
      frdm-imx95-all-features
      frdm-imx95-audio
      frdm-imx95-m7-remoteproc
      frdm-imx95-multimedia
      frdm-imx95-neutron-npu
      frdm-imx95-nvme
      frdm-imx95-wave6-vpu
    ];
  };

  flake.nixosModules.frdm-imx95-full = config.flake.modules.nixos.frdm-imx95-full;
}
