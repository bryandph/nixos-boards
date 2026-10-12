# FRDM-i.MX95 checks. Board modules collect every check in frdmChecks; the
# ones that need operator-supplied (R2) NXP files or build an NXP kernel are
# hardware checks, the rest run in CI (board-layout spec).
{
  flake-parts-lib,
  lib,
  ...
}: let
  hardwareOnly = [
    "all-features-kernel"
    "m7-source-container-structure"
    "neutron-default-closure-independence"
    "neutron-kernel-reduced"
    "neutron-kernel-reference"
    "sd-image-layout"
    "source-container-reproducibility"
    "source-container-structure"
    "source-sd-image-layout"
  ];
in {
  options.perSystem = flake-parts-lib.mkPerSystemOption {
    options.frdmChecks = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
      internal = true;
      description = "Every FRDM-i.MX95 check, before the CI and hardware split.";
    };
  };

  config.perSystem = {config, ...}: {
    checks = lib.mapAttrs' (name: lib.nameValuePair "frdm-imx95-${name}") (removeAttrs config.frdmChecks hardwareOnly);
    hardwareChecks.frdm-imx95 = lib.getAttrs (lib.filter (name: config.frdmChecks ? ${name}) hardwareOnly) config.frdmChecks;
  };
}
