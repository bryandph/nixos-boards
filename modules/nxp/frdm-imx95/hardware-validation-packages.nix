{
  config,
  inputs,
  lib,
  ...
}: let
  frdm = import ./_scope.nix {inherit config;};
  boardsLib = config.boards.lib;
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    scope = frdm (import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.unfreePackages [config.boards.manifests.frdm-imx95]);
    });
  in
    lib.mkIf (system == "aarch64-linux") (
      let
        audioSmoke = scope.audioSmoke;
        nvmeSmoke = scope.nvmeSmoke;
        hardwareBoard = inputs.nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            config.flake.modules.nixos.frdm-imx95-core
            config.flake.modules.nixos.frdm-imx95-all-features
            config.flake.modules.nixos.frdm-imx95-audio
            config.flake.modules.nixos.frdm-imx95-nvme
            {
              fileSystems."/".device = "/dev/disk/by-label/NIXOS_SD";
              fileSystems."/".fsType = "ext4";
              system.stateVersion = "26.05";
            }
          ];
        };
      in {
        boardPackages.frdm-imx95 = {
          frdm-imx95-audio-smoke = audioSmoke;
          frdm-imx95-nvme-smoke = nvmeSmoke;
        };

        frdmChecks = {
          hardware-validation-module-policy = pkgs.runCommand "frdm-imx95-hardware-validation-module-policy" {} ''
            test ${lib.escapeShellArg hardwareBoard.config.boot.kernelPackages.kernel.providerKind} = \
              nxp-full-combined
            test ${
              if builtins.elem "audio" hardwareBoard.config.boot.kernelPackages.kernel.capabilities
              then "1"
              else "0"
            } = 1
            test ${
              if builtins.elem "nvme" hardwareBoard.config.boot.kernelPackages.kernel.capabilities
              then "1"
              else "0"
            } = 1
            test ${
              if builtins.hasAttr "audio" hardwareBoard.config.users.groups
              then "1"
              else "0"
            } = 1
            test ${
              if builtins.elem audioSmoke hardwareBoard.config.environment.systemPackages
              then "1"
              else "0"
            } = 1
            test ${
              if builtins.elem nvmeSmoke hardwareBoard.config.environment.systemPackages
              then "1"
              else "0"
            } = 1
            if grep -Eq 'hw:[0-9]' ${../../../packages/nxp/frdm-imx95/scripts/frdm-imx95-audio-smoke}; then
              echo "audio smoke must not select cards by numeric order" >&2
              exit 1
            fi
            touch "$out"
          '';
        };
      }
    );
}
