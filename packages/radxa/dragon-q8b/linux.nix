{
  lib,
  buildLinux,
  fetchFromGitHub,
  ...
}: let
  pin = (import ./sources.nix).radxa;
in
  buildLinux {
    inherit (pin) version;
    modDirVersion = pin.version;
    src = fetchFromGitHub {
      owner = "radxa";
      repo = "kernel";
      inherit (pin) rev hash;
    };
    defconfig = "defconfig";
    autoModules = true;
    structuredExtraConfig = with lib.kernel; {
      ARCH_QCOM = yes;
      ARM64_4K_PAGES = yes;
      EFI = yes;
      EFI_STUB = yes;
      SERIAL_QCOM_GENI = yes;
      SERIAL_QCOM_GENI_CONSOLE = yes;
      MMC_SDHCI_MSM = module;
      PHY_QCOM_QMP_PCIE = module;
      PCIE_QCOM = yes;
      SCSI_UFSHCD = module;
      SCSI_UFS_QCOM = module;
      NVME_CORE = module;
      BLK_DEV_NVME = module;
    };
    extraMeta = {
      branch = "7.0";
      description = "Radxa Dragon Q8B vendor kernel, immutable source pin";
    };
    passthru.provider = pin.provider;
  }
