{
  config,
  lib,
  ...
}: let
  boardsLib = config.boards.lib;
  # Generated wiki pages for every registered board (D10).
  pages = lib.concatMapAttrs (_: entry:
    boardsLib.docPages {
      inherit (entry) page functions haveHardware;
      manifests = map (name: config.boards.manifests.${name}) entry.manifests;
    })
  config.boards.registry;
  wiki = lib.fileset.toSource {
    root = ../docs/wiki;
    fileset = ../docs/wiki;
  };
in {
  perSystem = {pkgs, ...}: let
    header = pkgs.writeText "generated-header" (lib.removeSuffix "\n" boardsLib.generatedHeader);
    docs = pkgs.runCommand "nixos-boards-docs" {} ''
      mkdir -p "$out"
      ${lib.concatStrings (lib.mapAttrsToList (name: text: ''
          cp ${pkgs.writeText name text} "$out/${name}"
        '')
        pages)}
    '';
  in {
    packages.docs = docs;

    apps.write-docs = {
      type = "app";
      meta.description = "Regenerate the generated wiki pages in docs/wiki";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "write-docs";
        runtimeInputs = [pkgs.coreutils pkgs.git pkgs.gnugrep];
        text = ''
          root=$(git rev-parse --show-toplevel)
          cd "$root/docs/wiki"
          # Remove generated pages that are no longer produced.
          stale=$(grep -l -F -x -f ${header} -- *.md) || [ "$?" -eq 1 ]
          if [ -n "$stale" ]; then
            echo "$stale" | xargs rm -f
          fi
          for page in ${docs}/*.md; do
            [ -e "$page" ] || continue
            install -m644 "$page" .
          done
          echo "Generated pages written to docs/wiki."
        '';
      });
    };

    checks = {
      # GitHub wiki pages link to each other by page name, e.g.
      # `[Glossary](Glossary)`. Every such link must name a page in
      # docs/wiki, which CI mirrors to the GitHub wiki.
      wiki-links = pkgs.runCommand "nixos-boards-wiki-links" {inherit wiki;} ''
        cd "$wiki"
        # Dotted board page names must be parsed, including a missing target.
        dotted=$(printf '%s\n' '[probe](FRDM-i.MX95-Definitely-Missing#section)' | grep -oE '\]\([A-Za-z0-9_.-]+(#[A-Za-z0-9_-]+)?\)' | sed -E 's/^\]\(([^)#]+).*/\1/')
        test "$dotted" = 'FRDM-i.MX95-Definitely-Missing'
        test ! -f "$dotted.md"
        status=0
        for page in *.md; do
          for target in $(grep -oE '\]\([A-Za-z0-9_.-]+(#[A-Za-z0-9_-]+)?\)' "$page" | sed -E 's/^\]\(([^)#]+).*/\1/' | sort -u); do
            if [ ! -f "$target.md" ]; then
              echo "$page links to missing wiki page $target" >&2
              status=1
            fi
          done
        done
        [ "$status" -eq 0 ]
        touch "$out"
      '';

      # Committed generated pages must match the generator.
      docs-drift = pkgs.runCommand "nixos-boards-docs-drift" {inherit wiki docs;} ''
        status=0
        for page in "$docs"/*.md; do
          [ -e "$page" ] || continue
          name=$(basename "$page")
          if ! cmp -s "$page" "$wiki/$name"; then
            echo "docs/wiki/$name is missing or out of date" >&2
            status=1
          fi
        done
        for page in "$wiki"/*.md; do
          name=$(basename "$page")
          if grep -q -F -x -f ${header} "$page" && [ ! -e "$docs/$name" ]; then
            echo "docs/wiki/$name is a generated page that is no longer produced" >&2
            status=1
          fi
        done
        if [ "$status" -ne 0 ]; then
          echo "Run: nix run .#write-docs" >&2
          exit 1
        fi
        touch "$out"
      '';
    };
  };
}
