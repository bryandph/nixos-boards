{lib, ...}: {
  perSystem = {pkgs, ...}: {
    # GitHub wiki pages link to each other by page name, e.g.
    # `[Glossary](Glossary)`. Every such link must name a page in
    # docs/wiki, which CI mirrors to the GitHub wiki.
    checks.wiki-links =
      pkgs.runCommand "nixos-boards-wiki-links" {
        wiki = lib.fileset.toSource {
          root = ../docs/wiki;
          fileset = ../docs/wiki;
        };
      } ''
        cd "$wiki"
        status=0
        for page in *.md; do
          for target in $(grep -oE '\]\([A-Za-z0-9_-]+(#[A-Za-z0-9_-]+)?\)' "$page" | sed -E 's/^\]\(([^)#]+).*/\1/' | sort -u); do
            if [ ! -f "$target.md" ]; then
              echo "$page links to missing wiki page $target" >&2
              status=1
            fi
          done
        done
        [ "$status" -eq 0 ]
        touch "$out"
      '';
  };
}
