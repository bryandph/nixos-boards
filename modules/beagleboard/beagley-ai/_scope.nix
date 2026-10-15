# BeagleY-AI package scope: callPackage with `beagleyArtifact` (an artifact
# from the release manifest) and `beagleyBuilt` (register a package built
# from manifest inputs) in addition to nixpkgs.
{config}: let
  boardsLib = config.boards.lib;
  manifest = config.boards.manifests.beagley-ai;
in
  pkgs:
    pkgs.lib.makeScope pkgs.newScope (_: {
      beagleyArtifact = id: boardsLib.mkArtifact {inherit pkgs manifest id;};
      beagleyBuilt = id: package: boardsLib.mkBuilt {inherit manifest id package;};
    })
