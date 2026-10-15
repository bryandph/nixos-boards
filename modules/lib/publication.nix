{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.boards;
  boardsLib = cfg.lib;
  # Ordinary cache configuration and explicit build targets.
  cache = {
    name = "bph";
    substituter = "https://bph.cachix.org";
    publicKey = "bph.cachix.org-1:RAjeSPL3sh3IBdCkXFV9x7V0EI7bHuV5Uzr4GeKteP4=";
  };
  # Opt-in consumer module; board features never import it.
  cacheModule = {
    nix.settings = {
      extra-substituters = [cache.substituter];
      extra-trusted-public-keys = [cache.publicKey];
    };
  };
in {
  flake = {
    modules.nixos.nixos-boards-cache = cacheModule;
    modules.darwin.nixos-boards-cache = cacheModule;
    nixosModules.nixos-boards-cache = cacheModule;
    darwinModules.nixos-boards-cache = cacheModule;
  };

  perSystem = {
    pkgs,
    system,
    ...
  }: let
    artifactPkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    pushSet = board: entry:
      boardsLib.mkPublicPushSet {
        inherit pkgs;
        name = "${board}-public-push-set";
        fixture = config.flake.nixosConfigurations."${board}-free";
        inherit (entry) publish;
        artifacts = lib.concatLists (lib.mapAttrsToList (manifest: ids:
          map (id:
            boardsLib.mkArtifact {
              pkgs = artifactPkgs;
              manifest = cfg.manifests.${manifest};
              inherit id;
            })
          ids)
        entry.publishArtifacts);
      };
    boardsHere = lib.filterAttrs (board: _: config.flake.nixosConfigurations."${board}-free".pkgs.stdenv.hostPlatform.system == system) cfg.registry;
  in {
    legacyPackages.publicPushSet = lib.mapAttrs pushSet boardsHere;
  };
}
