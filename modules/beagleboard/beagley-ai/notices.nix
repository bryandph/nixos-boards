# Notices for the TI tool artifacts that carry none of their own: each
# artifact pins its upstream notices, and the packages built from them copy
# those notices into their own share/licenses (the pycls MIT notice must
# accompany every copy of the RegNet model).
{
  config,
  lib,
  ...
}: let
  manifest = config.boards.manifests.beagley-ai;
  urls = id: map (n: n.url) manifest.artifacts.${id}.notices;
  pins = id: needle: lib.any (lib.hasInfix needle) (urls id);
in {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    built = config.legacyPackages.beagley-ai or {};
    copies = name: dest: !(built ? ${name}) || lib.hasInfix "share/licenses/${dest}" built.${name}.buildCommand;
  in {
    checks.beagley-ai-tool-notices = assert pins "regnet-archive" "facebookresearch/pycls";
    assert pins "regnet-archive" "edgeai-modelzoo";
    assert pins "tidl-tools" "edgeai-tidl-tools";
    assert pins "tidlruntime-wheel" "edgeai-tidl-tools";
    assert copies "regnet-model" "beagley-ai-regnet-model";
    assert copies "model-tools" "beagley-ai-model-tools";
    assert copies "osrt" "beagley-ai-osrt/tidlruntime";
      pkgs.runCommand "beagley-ai-tool-notices" {} "touch $out";
  };
}
