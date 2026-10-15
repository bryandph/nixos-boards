{
  config,
  inputs,
  lib,
  ...
}: let
  boardsLib = import ./_boards-lib.nix {inherit lib;};
  inherit (lib) mkOption types;
  cfg = config.boards;
  manifestsOf = board: map (name: cfg.manifests.${name}) cfg.registry.${board}.manifests;

  functionType = types.submodule {
    options = {
      status = mkOption {
        type = types.enum ["verified" "implemented-unverified" "blocked" "pending"];
        description = "Hardware acceptance status (D10).";
      };
      reason = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Named impediment when blocked, e.g. `licensing`.";
      };
      evidence = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Link to the observation that verified the function.";
      };
      features = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Features that provide the function.";
      };
    };
  };

  entryType = types.submodule ({name, ...}: {
    options = {
      system = mkOption {
        type = types.str;
        default = "aarch64-linux";
        description = "Platform of the board's fixtures (`nixpkgs.hostPlatform`).";
      };
      page = mkOption {
        type = types.str;
        default = name;
        description = "Wiki page name prefix for the board, e.g. `Dragon-Q8B`.";
      };
      free = mkOption {
        type = types.listOf types.deferredModule;
        description = "Modules of the free profile: core, image and every free feature.";
      };
      full = mkOption {
        type = types.listOf types.deferredModule;
        default = [];
        description = "Modules the full profile adds, normally `<board>-full`.";
      };
      manifests = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Release manifests whose artifacts this board's features use.";
      };
      functions = mkOption {
        type = types.attrsOf functionType;
        default = {};
        description = "Hardware functions and their acceptance status, for the hardware matrix.";
      };
      publish = mkOption {
        type = types.listOf types.str;
        default = ["toplevel"];
        description = "Ordinary build targets from the free fixture's `system.build`, e.g. `sdImage`; not a publication-permission decision.";
      };
      publishArtifacts = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
        description = "Explicit standalone artifact targets, keyed by release manifest and artifact identifier; not selected by license flags.";
      };
      haveHardware = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the maintainers have this board for verification.";
      };
    };
  });

  # Public fixtures (D7/D9). Features never set nixpkgs.config: the free
  # profile forbids every non-free and non-source package, and the full
  # profile admits exactly the board's manifest artifacts.
  mkFixtures = {
    board,
    entry,
    manifests,
  }: let
    names = boardsLib.unfreePackages manifests;
    manifestNames = map (m: m.name) manifests;
    base = profile: {
      lib,
      config,
      options,
      ...
    }: {
      _file = "nixos-boards#fixture";
      networking.hostName = lib.mkDefault board;
      nixpkgs.hostPlatform = lib.mkDefault entry.system;
      # Public fixture: local serial login only, no credentials or SSH.
      services.getty.autologinUser = "root";
      services.openssh.enable = false;
      system.stateVersion = "26.05";
      nixpkgs.config =
        if profile == "free"
        then boardsLib.freeNixpkgsConfig
        else {allowUnfreePredicate = boardsLib.namePredicate names;};
      assertions =
        [
          {
            assertion = lib.all (d: d.file == "nixos-boards#fixture") options.nixpkgs.config.definitionsWithLocations;
            message = "${board}: features must not set nixpkgs.config; non-free allowances come from release manifests";
          }
          {
            assertion = config.hardware.boards.identity.board == board;
            message = "${board}: hardware.boards.identity.board is ${config.hardware.boards.identity.board}";
          }
          {
            assertion = config.hardware.boards.image.layoutVersion != null;
            message = "${board}: the free profile must include ${board}-image, which sets hardware.boards.image.layoutVersion";
          }
        ]
        ++ map (p: {
          assertion = builtins.elem (p.manifestEntry.manifest or null) manifestNames;
          message = "${board}: artifact ${p.name} comes from a manifest not listed in boards.registry.${board}.manifests";
        })
        config.hardware.boards.artifacts;
    };
    system = profile: modules:
      inputs.nixpkgs.lib.nixosSystem {
        modules = [config.flake.modules.nixos.hardware-boards (base profile)] ++ modules;
      };
  in {
    free = system "free" entry.free;
    full = system "full" (entry.free ++ entry.full);
  };

  # Evaluate a configuration completely (assertions, package metadata)
  # without building it.
  evaluates = nixos: builtins.unsafeDiscardStringContext nixos.config.system.build.toplevel.drvPath;

  fixtures = lib.mapAttrs (board: entry:
    mkFixtures {
      inherit board entry;
      manifests = manifestsOf board;
    })
  cfg.registry;
in {
  options.boards = {
    lib = mkOption {
      type = types.raw;
      readOnly = true;
      default = boardsLib;
      description = "The board-support library (`modules/lib/_boards-lib.nix`).";
    };
    internal = mkOption {
      type = types.raw;
      readOnly = true;
      internal = true;
      default = {inherit mkFixtures evaluates entryType;};
      description = "Fixture factory shared with the library tests.";
    };
    manifests = mkOption {
      type = types.attrsOf boardsLib.types.manifest;
      default = {};
      description = "Release manifests keyed by name (D6).";
    };
    registry = mkOption {
      type = types.attrsOf entryType;
      default = {};
      description = "Supported boards keyed by board identifier (D1).";
    };
  };

  config = {
    flake = {
      lib =
        boardsLib
        // {
          # Generated from manifests (D6/D7); never written by hand.
          unfreePackages = lib.mapAttrs (board: _: boardsLib.unfreePackages (manifestsOf board)) cfg.registry;
          unfreePredicate = board: boardsLib.namePredicate config.flake.lib.unfreePackages.${board};
        };
      nixosConfigurations = lib.concatMapAttrs (board: f:
        {"${board}-free" = f.free;}
        // lib.optionalAttrs (cfg.registry.${board}.full != []) {"${board}-full" = f.full;})
      fixtures;
    };

    perSystem = {pkgs, ...}: let
      unknown = lib.concatLists (lib.mapAttrsToList (board: b:
        map (m: "${board}: unknown release manifest ${m}")
        (lib.filter (m: !(cfg.manifests ? ${m})) b.manifests))
      cfg.registry);
      errors = unknown ++ lib.concatMap boardsLib.manifestErrors (lib.attrValues cfg.manifests);
    in {
      checks =
        {
          release-manifests = pkgs.runCommand "nixos-boards-release-manifests" {} (
            if errors == []
            then "touch $out"
            else ''
              cat >&2 <<'EOF'
              ${lib.concatStringsSep "\n" errors}
              EOF
              exit 1
            ''
          );
        }
        // lib.concatMapAttrs (board: f:
          {
            "${board}-free" = pkgs.writeText "${board}-free-evaluates" (evaluates f.free);
          }
          // lib.optionalAttrs (cfg.registry.${board}.full != []) {
            "${board}-full" = pkgs.writeText "${board}-full-evaluates" (evaluates f.full);
          })
        fixtures;
    };
  };
}
