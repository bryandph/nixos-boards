# FRDM-i.MX95 publication: every NXP-licensed file, including the eIQ
# Neutron SDK and its converted model, permits internal build and private
# cache copies, and none permits a public form.
{
  config,
  lib,
  ...
}: let
  manifest = config.boards.manifests.frdm-imx95;
  eiq = lib.getAttrs ["eiq-neutron-sdk-wheel" "neutron-converted-model"] manifest.artifacts;
  eiqBuilt = lib.getAttrs ["eiq-neutron-sdk" "neutron-model" "neutron-smoke"] manifest.built;
  forms = r: lib.filter (form: r.${form} or false) ["file" "image" "cache"];
  full = config.flake.nixosConfigurations.frdm-imx95-full.config.hardware.boards.publication;
in {
  perSystem = {pkgs, ...}: {
    frdmChecks.publication = assert full.build && full.private && full.buildBlocking == [];
    assert lib.all (a: a.redistribution.private or false) (lib.attrValues (eiq // eiqBuilt));
    assert lib.all (a: forms a.redistribution == []) (lib.attrValues eiq);
      pkgs.runCommand "frdm-imx95-publication" {} "touch $out";
  };
}
