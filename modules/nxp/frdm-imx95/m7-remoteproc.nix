# Cortex-M7 under Linux remoteproc: System Manager policy that hands the M7
# to Linux, the fsl,imx95-cm7 node and the guarded m7-ctl tool. Consumers
# add their M7 ELF firmware to hardware.firmware; m7-ctl loads
# frdm-imx95/frdm-imx95-m7-smoke.elf unless told otherwise.
{config, ...}: let
  frdm = import ./_scope.nix {inherit config;};
  inherit (config.flake.modules.nixos) frdm-imx95-image;
in {
  flake.modules.nixos.frdm-imx95-m7-remoteproc = {
    config,
    lib,
    pkgs,
    ...
  }: let
    scope = frdm pkgs;
    m7BootContainer = scope.m7SourceBootContainer.override {
      expectedBootContainerSha256 = config.hardware.boards.imx95.m7BootContainerSha256;
    };
    m7Ctl = scope.m7Ctl;
    providerKind = config.boot.kernelPackages.kernel.providerKind or "upstream";
    usesCombinedNxpProvider = providerKind == "nxp-full-combined";
  in {
    imports = [frdm-imx95-image];
    hardware.boards.imx95.bootContainer = lib.mkOverride 900 m7BootContainer;
    hardware.boards.claims = [
      {
        resource = "remoteproc:m7";
        owner = "frdm-imx95-m7-remoteproc";
      }
    ];

    hardware.deviceTree.overlays = lib.mkIf (!usesCombinedNxpProvider) [
      {
        name = "frdm-imx95-m7-remoteproc";
        filter = "imx95-15x15-frdm.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
            compatible = "fsl,imx95-15x15-frdm";

            fragment@0 {
              target-path = "/";

              __overlay__ {
                imx95-cm7 {
                  compatible = "fsl,imx95-cm7";
                  mbox-names = "tx", "rx", "rxdb";
                  mboxes = <&mu7 0 1>,
                            <&mu7 1 1>,
                            <&mu7 3 1>;
                  memory-region = <&vdevbuffer>,
                                  <&vdev0vring0>,
                                  <&vdev0vring1>,
                                  <&vdev1vring0>,
                                  <&vdev1vring1>,
                                  <&rsc_table>;
                  status = "okay";
                };
              };
            };
          };
        '';
      }
    ];

    environment.systemPackages = [m7Ctl];

    assertions = [
      {
        assertion =
          (config.hardware.boards.imx95.bootContainer.systemManagerPolicy or null)
          == "m7-remoteproc-lmm"
          && !(config.hardware.boards.imx95.bootContainer.containsM7Application or false);
        message = "FRDM-i.MX95 M7 remoteproc requires the m7-remoteproc-lmm System Manager policy and no preloaded M7 application; consumer overrides must retain that contract.";
      }
      {
        assertion =
          usesCombinedNxpProvider
          || (
            providerKind
            == "upstream"
            && lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.1"
          );
        message = ''
          FRDM-i.MX95 M7 remoteproc requires either upstream Linux 7.1 or
          newer, or the reviewed NXP combined provider with native
          fsl,imx95-cm7 support.
        '';
      }
    ];
  };

  flake.nixosModules.frdm-imx95-m7-remoteproc = config.flake.modules.nixos.frdm-imx95-m7-remoteproc;
}
