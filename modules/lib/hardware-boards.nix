{config, ...}: let
  boardsLib = config.boards.lib;
in {
  # Board description options (D2). Every board core imports this module;
  # the explicit key lets several cores and add-ons import it once.
  flake.modules.nixos.hardware-boards = {
    config,
    lib,
    ...
  }: let
    inherit (lib) mkOption types;
    cfg = config.hardware.boards;
  in {
    key = "nixos-boards#hardware-boards";

    options.hardware.boards = {
      identity = {
        board = mkOption {
          type = types.str;
          description = "Board identifier, e.g. `beagley-ai`.";
        };
        vendor = mkOption {
          type = types.str;
          description = "Board vendor.";
        };
        soc = mkOption {
          type = types.str;
          description = "SoC identifier, e.g. `am67a` or `sc8280xp`.";
        };
        bootChain = mkOption {
          type = types.enum ["image" "vendor-partition" "board"];
          description = "Who owns the firmware that runs before NixOS (D4).";
        };
        provider = mkOption {
          type = types.str;
          description = ''
            Provider of the board's kernel, device tree and firmware (D3):
            `mainline`, `mainline+<series>` or `<vendor>-<release>`. The
            kernel must carry the same `passthru.provider`.
          '';
        };
        statusPage = mkOption {
          type = types.str;
          default = "https://github.com/bryandph/nixos-boards/wiki/${cfg.identity.board}";
          defaultText = lib.literalExpression ''"https://github.com/bryandph/nixos-boards/wiki/''${board}"'';
          description = "Board status page, named in provider warnings.";
        };
      };

      connectors = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            standard = mkOption {
              type = types.str;
              description = "Connector standard, e.g. `rpi-40pin`, `pmod`, `m2-e`, `csi-2-22pin`.";
            };
            bindings = mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = ''
                Pinout binding: connector-standard signal names mapped to this
                board's buses, pins or device-tree labels, e.g.
                `{ i2c = "&main_i2c1"; uart = "&main_uart6"; }`.
              '';
            };
          };
        });
        default = {};
        description = "Connectors add-ons attach to, keyed by board-local name (e.g. `header`, `csi0`).";
      };

      claims = mkOption {
        type = types.listOf (types.submodule {
          options = {
            resource = mkOption {
              type = types.str;
              description = "Claimed resource, `<connector-or-bus>:<item>`, e.g. `header:8`, `i2c1:0x50`, `remoteproc:m7`.";
            };
            owner = mkOption {
              type = types.str;
              description = "Feature or add-on making the claim.";
            };
          };
        });
        default = [];
        description = "Resource claims; a resource claimed by two owners fails evaluation.";
      };

      artifacts = mkOption {
        type = types.listOf types.package;
        default = [];
        description = ''
          Artifact packages built from release manifests that this
          configuration uses. Features add every manifest artifact they
          install here; documentation and publication gates read it.
        '';
      };
    };

    config.warnings = lib.optional (!lib.hasPrefix "mainline" cfg.identity.provider) ''
      ${cfg.identity.board} uses the ${cfg.identity.provider} provider, not mainline. See ${cfg.identity.statusPage}.
    '';

    config.assertions =
      [
        {
          assertion = (config.boot.kernelPackages.kernel.provider or null) == cfg.identity.provider;
          message = "${cfg.identity.board}: the kernel's provider (${toString (config.boot.kernelPackages.kernel.provider or "unlabelled")}) is not ${cfg.identity.provider}";
        }
      ]
      ++ map (p: {
        assertion = builtins.elem p.manifestEntry.provider ["any" cfg.identity.provider];
        message = "${cfg.identity.board}: ${p.name} comes from provider ${p.manifestEntry.provider}, not ${cfg.identity.provider}";
      }) (lib.filter (p: p ? manifestEntry && builtins.elem p.manifestEntry.layer ["kernel" "runtime-firmware"]) cfg.artifacts)
      ++ map (message: {
        assertion = false;
        message = "hardware.boards.claims: ${message}";
      }) (boardsLib.claimConflicts cfg.claims)
      ++ map (p: {
        assertion = p ? manifestEntry;
        message = "hardware.boards.artifacts: ${p.name or "a package"} was not built from a release manifest";
      })
      cfg.artifacts;
  };

  flake.nixosModules.hardware-boards = config.flake.modules.nixos.hardware-boards;
}
