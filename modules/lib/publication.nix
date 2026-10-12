{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.boards;
  boardsLib = cfg.lib;
  # Public lane (D8).
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
    pushSet = board: entry: let
      manifests = map (n: cfg.manifests.${n}) entry.manifests;
    in
      boardsLib.mkPublicPushSet {
        name = "${board}-public-push-set";
        fixture = config.flake.nixosConfigurations."${board}-free";
        inherit (entry) publish;
        inherit manifests;
        # Admits only cache-cleared names, so nothing else can evaluate.
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.cacheablePackages manifests);
        };
      };
    boardsHere = lib.filterAttrs (board: _: config.flake.nixosConfigurations."${board}-free".pkgs.stdenv.hostPlatform.system == system) cfg.registry;
    cacheScan = boardsLib.mkCacheScan {
      inherit pkgs;
      hashes = boardsLib.nonCacheableHashes (lib.attrValues cfg.manifests);
    };
  in {
    legacyPackages.publicPushSet = lib.mapAttrs pushSet boardsHere;
    packages.cache-scan = cacheScan;
    apps.cache-scan = {
      type = "app";
      meta.description = "Scan store paths for artifacts not cleared for the public cache (gate 2)";
      program = lib.getExe cacheScan;
    };
  };
}
