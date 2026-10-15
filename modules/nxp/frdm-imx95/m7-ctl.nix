{
  config,
  inputs,
  ...
}: let
  frdm = import ./_scope.nix {inherit config;};
  boardsLib = config.boards.lib;
in {
  perSystem = {system, ...}: let
    scope = frdm (import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.unfreePackages [config.boards.manifests.frdm-imx95]);
    });
  in {
    boardPackages.frdm-imx95.frdm-imx95-m7-ctl =
      scope.m7Ctl;
  };
}
