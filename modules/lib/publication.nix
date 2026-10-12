{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.boards;
  boardsLib = cfg.lib;
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    # Gate 1 (D8): the public push set holds the free fixture's builds and
    # the R1 artifacts cleared for `cache`, rebuilt with nixpkgs that admits
    # only cacheable names. Anything else fails evaluation.
    pushSet = board: entry: let
      fixture = config.flake.nixosConfigurations."${board}-free";
      manifests = map (n: cfg.manifests.${n}) entry.manifests;
      cachePkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.cacheablePackages manifests);
      };
      artifacts = lib.concatMap (m:
        lib.mapAttrsToList (id: _:
          boardsLib.mkArtifact {
            pkgs = cachePkgs;
            manifest = m;
            inherit id;
          })
        (lib.filterAttrs (_: a: a.status == "adopted" && a.class == "R1" && a.redistribution.cache) m.artifacts))
      manifests;
    in
      pkgs.linkFarmFromDrvs "${board}-public-push-set"
      (map (attr: fixture.config.system.build.${attr}) entry.publish ++ artifacts);
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
