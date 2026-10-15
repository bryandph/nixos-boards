{config, ...}: let
  beagley = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.beagley-ai-remoteproc-ipc = {
    config,
    pkgs,
    ...
  }: let
    ipcFirmware = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/accelerator-ipc-firmware.nix {};
  in {
    imports = [./_remoteproc.nix];
    hardware.beagleyAi.remoteprocOwner = "ipc";
    environment.systemPackages = [((beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/accelerator-ipc-test.nix {})];
    hardware.firmware = [ipcFirmware];
    hardware.boards.artifacts = [ipcFirmware];
    system.build.beagleyAiAcceleratorDeviceTreeCheck = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/accelerator-dt-check.nix {
      deviceTree = config.hardware.deviceTree.package;
      profile = "ipc";
    };
    system.extraDependencies = [config.system.build.beagleyAiAcceleratorDeviceTreeCheck];
    hardware.deviceTree.overlays = [
      {
        name = "beagley-ai-ipc";
        filter = "k3-am67a-beagley-ai";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "beagle,am67a-beagley-ai";
            fragment@0 {
              target-path = "/bus@f0000/dsp@7e200000";
              __overlay__ { status = "okay"; };
            };
          };
        '';
      }
    ];
  };

  flake.nixosModules.beagley-ai-remoteproc-ipc = config.flake.modules.nixos.beagley-ai-remoteproc-ipc;
}
