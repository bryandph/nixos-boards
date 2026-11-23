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
  bundle = (lib.head sourceFiles).sourceFile.bundle;
  records = lib.unique (map (file: {
      inherit (file) url sha256;
      inherit (file.sourceFile) path;
    })
    sourceFiles);
  sortFiles = lib.sort (a: b: a.url < b.url);
in {
  perSystem = {pkgs, ...}: let
    source = boardsLib.mkSourceBundle {inherit pkgs bundle;};
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
    assert builtins.length records == 11;
    assert sortFiles bundle.files == sortFiles records;
    assert lib.all (file: file.url == "https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/plain/${file.path}?id=d528873a75e532075a1fd5d2a53defef98d60437") bundle.files;
    assert lib.all (file: file.sourceFile.bundle == bundle) sourceFiles;
      pkgs.runCommand "beagley-ai-ti-firmware-source" {} ''
        # Check the fetched inventory and every manifest file hash.
        test "$(find ${source} -type f | wc -l)" -eq 11
        ${lib.concatMapStrings (file: ''
          echo '${builtins.convertHash {
            hash = file.sha256;
            toHashFormat = "base16";
          }}  ${source}/${file.sourceFile.path}' | sha256sum -c
        '') (lib.unique sourceFiles)}
        touch "$out"
      '';
  };
}
