# Keep the shared TI fetch bounded and its per-file fixed-output identities
# compatible with the original URL fetches, including every notice name.
{
  config,
  lib,
  ...
}: let
  boardsLib = config.boards.lib;
  manifest = config.boards.manifests.beagley-ai;
  artifacts = lib.filterAttrs (_: a: a.sourceFile != null) manifest.artifacts;
  sourceFiles = lib.concatMap (a: [a] ++ a.notices) (lib.attrValues artifacts);
  tree = (lib.head sourceFiles).sourceFile.tree;
  paths = lib.unique (map (file: file.sourceFile.path) sourceFiles);
in {
  perSystem = {pkgs, ...}: let
    # Include TI notices attached to non-TI artifacts (e.g. SDK tools).
    compatible = lib.all (id: let
      a = manifest.artifacts.${id};
      package = boardsLib.mkArtifact {inherit pkgs manifest id;};
      oldFile = name: file:
        pkgs.fetchurl {
          inherit name;
          inherit (file) url;
          hash = file.sha256;
        };
      noticesCompatible = lib.imap0 (i: notice:
        notice.sourceFile
        == null
        || lib.hasInfix (builtins.unsafeDiscardStringContext (toString (oldFile "${manifest.name}-${id}-notice-${toString i}" notice))) package.installPhase)
      a.notices;
    in
      (a.sourceFile == null || lib.hasInfix (builtins.unsafeDiscardStringContext (toString (oldFile (baseNameOf a.path) a))) package.installPhase)
      && lib.all (x: x) noticesCompatible)
    (lib.attrNames manifest.artifacts);
  in {
    checks.beagley-ai-ti-firmware-source = assert compatible;
    assert builtins.length paths == 11;
    assert lib.sort builtins.lessThan tree.sparseCheckout == lib.sort builtins.lessThan (map (path: "/${path}") paths);
    assert lib.all (file: file.sourceFile.tree == tree) sourceFiles;
      pkgs.runCommand "beagley-ai-ti-firmware-source" {} ''
        # Check the actual sparse output as well as its declared patterns.
        test "$(find ${pkgs.fetchgit tree} -type f | wc -l)" -eq 11
        ${lib.concatMapStrings (file: ''
          echo '${builtins.convertHash {
            hash = file.sha256;
            toHashFormat = "base16";
          }}  ${pkgs.fetchgit tree}/${file.sourceFile.path}' | sha256sum -c
        '') (lib.unique sourceFiles)}
        touch "$out"
      '';
  };
}
