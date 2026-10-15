{
  config,
  lib,
  ...
}: let
  beagley = import ./_scope.nix {inherit config;};
  regions = import ../../../packages/beagleboard/beagley-ai/accelerator-memory.nix;
in {
  flake.modules.nixos.beagley-ai-vision = {
    config,
    pkgs,
    ...
  }: let
    # TI's C7x tools are x86_64 binaries, so the firmware is built for
    # x86_64-linux with the configuration of the consumer's nixpkgs.
    x86 = beagley (import pkgs.path {
      system = "x86_64-linux";
      inherit (pkgs) config;
    });
    firmware = x86.callPackage ../../../packages/beagleboard/beagley-ai/accelerator-firmware.nix {};
  in {
    imports = [./_remoteproc.nix];
    hardware.boards.artifacts = [firmware];
    hardware.beagleyAi.remoteprocOwner = "vision";
    hardware.firmware = [firmware];
    system.build.beagleyAiAcceleratorDeviceTreeCheck = (beagley pkgs).callPackage ../../../packages/beagleboard/beagley-ai/accelerator-dt-check.nix {
      deviceTree = config.hardware.deviceTree.package;
      profile = "vision";
      inherit firmware;
    };
    system.extraDependencies = [config.system.build.beagleyAiAcceleratorDeviceTreeCheck];
    hardware.deviceTree.overlays = [
      {
        name = "beagley-ai-vision";
        filter = "k3-am67a-beagley-ai";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "beagle,am67a-beagley-ai";
            fragment@0 {
              target-path = "/reserved-memory";
              __overlay__ {
                #address-cells = <2>;
                #size-cells = <2>;
                linux,cma { status = "disabled"; };
                ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: region: ''
              ${name} {
                compatible = "${region.compatible or "shared-dma-pool"}";
                reg = <${lib.concatStringsSep " " region.reg}>;
                ${lib.optionalString (region.noMap or true) "no-map;"}
                ${lib.optionalString (region.cma or false) "reusable; linux,cma-default;"}
              };
            '')
            regions)}
              };
            };
            fragment@1 {
              target-path = "/bus@f0000/dsp@7e200000";
              __overlay__ { status = "okay"; };
            };
          };
        '';
      }
    ];
  };

  flake.nixosModules.beagley-ai-vision = config.flake.modules.nixos.beagley-ai-vision;
}
