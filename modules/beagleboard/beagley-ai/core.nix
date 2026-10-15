# BeagleY-AI (TI AM67A/J722S) core: the coordinated BeagleBoard 6.12
# kernel, device tree and board identity. Free; boot firmware and every
# accelerator, GPU and radio blob are separate features.
{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
  inherit (config.flake.modules.nixos) hardware-boards;
in {
  flake.modules.nixos.beagley-ai-core = {
    config,
    lib,
    pkgs,
    ...
  }: let
    release = import ../../../packages/beagleboard/beagley-ai/release.nix;
    kernel = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/linux.nix {};
  in {
    imports = [hardware-boards];
    hardware.boards.identity = {
      board = "beagley-ai";
      vendor = "beagleboard";
      soc = "am67a";
      bootChain = "image";
      inherit (release) provider;
      statusPage = "https://github.com/bryandph/nixos-boards/wiki/BeagleY-AI";
    };
    # This vendor kernel does not enable firmware decompression.
    hardware.firmwareCompression = lib.mkDefault "none";
    boot = {
      kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor kernel);
      kernelParams = ["console=${release.board.console}" "earlycon" "rootwait"];
      supportedFilesystems = lib.mkForce ["ext4" "vfat"];
      initrd.includeDefaultModules = false;
      initrd.systemd.tpm2.enable = lib.mkDefault false;
      initrd.availableKernelModules = ["mmc_block" "sdhci" "sdhci_am654"];
      loader = {
        grub.enable = false;
        generic-extlinux-compatible = {
          enable = true;
          configurationLimit = 5;
        };
      };
    };
    hardware.deviceTree = {
      enable = true;
      name = release.board.dtb;
      filter = "k3-am67a-beagley-ai*.dtb";
      overlays = [
        {
          name = "beagley-ai-rtc-order";
          filter = "k3-am67a-beagley-ai";
          # RTC aliases are not reserved globally. Give the early-probed
          # internal RTC an explicit ID so it cannot take the DS1340's rtc0.
          dtsText = ''
            /dts-v1/;
            /plugin/;
            / {
              compatible = "beagle,am67a-beagley-ai";
              fragment@0 {
                target-path = "/aliases";
                __overlay__ {
                  rtc1 = "/bus@f0000/bus@b00000/rtc@2b1f0000";
                };
              };
            };
          '';
        }
      ];
    };
    system.build.beagleyAiDeviceTreeCheck = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/device-tree-check.nix {
      deviceTree = config.hardware.deviceTree.package;
    };
    assertions = [
      {
        assertion = config.hardware.firmwareCompression == "none";
        message = "The BeagleY-AI kernel requires uncompressed firmware payloads.";
      }
      {
        assertion = config.hardware.deviceTree.name == release.board.dtb;
        message = "BeagleY-AI must use its matching board DTB.";
      }
    ];
  };

  flake.nixosModules.beagley-ai-core = config.flake.modules.nixos.beagley-ai-core;
}
