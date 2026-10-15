# Recorded FRDM-i.MX95 license/provenance declarations. These facts do
# not select CI publication targets or impose a placement/admission service.
{
  config,
  lib,
  ...
}: let
  manifest = config.boards.manifests.frdm-imx95;
  eiq = lib.getAttrs ["eiq-neutron-sdk-wheel" "neutron-converted-model"] manifest.artifacts;
  eiqBuilt = lib.getAttrs ["eiq-neutron-sdk" "neutron-model" "neutron-smoke"] manifest.built;
  forms = r: lib.filter (form: r.${form} or false) ["file" "image" "cache"];
in {
  perSystem = {pkgs, ...}: {
    frdmChecks.provenance = assert lib.all (a: a.redistribution.private or false) (lib.attrValues (eiq // eiqBuilt));
    assert lib.all (a: forms a.redistribution == []) (lib.attrValues eiq);
      pkgs.writeText "frdm-imx95-provenance" "Recorded eIQ license evidence and permission declarations.\n";
  };
}
