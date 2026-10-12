{
  config,
  lib,
  ...
}: let
  boardsLib = import ./_boards-lib.nix {inherit lib;};
  inherit (lib) mkOption types;
  cfg = config.boards;
  manifestsOf = board: map (name: cfg.manifests.${name}) cfg.registry.${board}.manifests;
in {
  options.boards = {
    lib = mkOption {
      type = types.raw;
      readOnly = true;
      default = boardsLib;
      description = "The board-support library (`modules/lib/_boards-lib.nix`).";
    };
    manifests = mkOption {
      type = types.attrsOf boardsLib.types.manifest;
      default = {};
      description = "Release manifests keyed by name (D6).";
    };
    registry = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          vendor = mkOption {type = types.str;};
          soc = mkOption {type = types.str;};
          bootChain = mkOption {type = types.enum ["image" "vendor-partition" "board"];};
          manifests = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Release manifests whose artifacts this board's features use.";
          };
        };
      });
      default = {};
      description = "Supported boards keyed by board identifier (D1).";
    };
  };

  config = {
    flake.lib =
      boardsLib
      // {
        # Generated from manifests (D6/D7); never written by hand.
        unfreePackages = lib.mapAttrs (board: _: boardsLib.unfreePackages (manifestsOf board)) cfg.registry;
        cacheablePackages = lib.mapAttrs (board: _: boardsLib.cacheablePackages (manifestsOf board)) cfg.registry;
        unfreePredicate = board: boardsLib.namePredicate config.flake.lib.unfreePackages.${board};
      };

    perSystem = {pkgs, ...}: let
      unknown = lib.concatLists (lib.mapAttrsToList (board: b:
        map (m: "${board}: unknown release manifest ${m}")
        (lib.filter (m: !(cfg.manifests ? ${m})) b.manifests))
      cfg.registry);
      errors = unknown ++ lib.concatMap boardsLib.manifestErrors (lib.attrValues cfg.manifests);
    in {
      checks.release-manifests = pkgs.runCommand "nixos-boards-release-manifests" {} (
        if errors == []
        then "touch $out"
        else ''
          cat >&2 <<'EOF'
          ${lib.concatStringsSep "\n" errors}
          EOF
          exit 1
        ''
      );
    };
  };
}
