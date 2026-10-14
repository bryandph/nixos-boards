# Pure board-support library: release-manifest types and validation,
# artifact derivations, unfree lists, resource-claim conflicts and the
# guarded firmware-flashing tool. Every function takes its data as
# arguments so tests can exercise it without registering anything.
{lib}: let
  inherit (lib) mkOption types;

  classes = ["R0" "R1" "R2"];
  layers = ["boot-firmware" "kernel" "runtime-firmware" "userspace"];
  loads = ["firmware" "boot-image" "boot-partition" "board-storage" "remoteproc" "userspace"];

  fileType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        description = "Pinned download URL.";
      };
      sha256 = mkOption {
        type = types.str;
        description = "SRI sha256 of the file.";
      };
    };
  };

  evidenceType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        description = "Where the license grant is published.";
      };
      retrieved = mkOption {
        type = types.strMatching "[0-9]{4}-[0-9]{2}-[0-9]{2}";
        description = "Date the evidence was read (YYYY-MM-DD).";
      };
      location = mkOption {
        type = types.str;
        description = "Where in the document the grant appears.";
      };
    };
  };

  redistributionDescriptions = {
    file = "The license permits redistributing the unmodified file.";
    image = "The license permits redistributing it inside an aggregate disk image.";
    cache = "The license permits publishing it as a binary-cache substitute.";
    private = "The license permits internal copies on the maintainer's private infrastructure.";
  };

  redistributionType = types.submodule {
    options = lib.mapAttrs (_: description:
      mkOption {
        type = types.bool;
        default = false;
        inherit description;
      })
    redistributionDescriptions;
  };

  artifactType = types.submodule {
    options = {
      status = mkOption {
        type = types.enum ["adopted" "blocked"];
        default = "adopted";
        description = "Blocked artifacts are documented but never fetched.";
      };
      blockedReason = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Named impediment for a blocked artifact, e.g. `licensing`.";
      };
      class = mkOption {
        type = types.enum classes;
        description = "Non-free class: R0 free, R1 redistributable, R2 operator-supplied.";
      };
      path = mkOption {
        type = types.str;
        description = "Installed path relative to the package output, e.g. `lib/firmware/vendor/x.bin`.";
      };
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Pinned download URL (R0 and R1).";
      };
      size = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "File size in bytes.";
      };
      sha256 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SRI sha256 of the file.";
      };
      derivedHashes = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "SRI sha256 hashes of forms the build derives from the file (e.g. compressed); used by the pre-push scan.";
      };
      license = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "A `lib.licenses` entry, or an attribute set with at least `shortName` and `free` for `LicenseRef-*` licenses.";
      };
      evidence = mkOption {
        type = types.nullOr evidenceType;
        default = null;
        description = "Where the license grant was established.";
      };
      notices = mkOption {
        type = types.listOf fileType;
        default = [];
        description = "License and notice files installed with the artifact.";
      };
      redistribution = mkOption {
        type = redistributionType;
        default = {};
        description = "Redistribution forms the license permits.";
      };
      instructions = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "How the operator obtains and imports an R2 artifact.";
      };
      layer = mkOption {
        type = types.enum layers;
        description = "Support layer the artifact belongs to.";
      };
      load = mkOption {
        type = types.enum loads;
        description = "How the artifact reaches the hardware.";
      };
      features = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Features (or functions) the artifact enables.";
      };
    };
  };

  manifestType = types.submodule ({name, ...}: {
    options = {
      name = mkOption {
        type = types.strMatching "[a-z0-9][a-z0-9-]*";
        default = name;
        description = "Manifest name; prefixes every artifact package name.";
      };
      provider = mkOption {
        type = types.str;
        description = "Provider label (D3), e.g. `mainline` or `radxa-7.0.11`; `any` for provider-independent releases such as linux-firmware.";
      };
      version = mkOption {
        type = types.str;
        description = "Release version of the pinned source.";
      };
      source = mkOption {
        type = types.str;
        description = "Human-readable description of the pinned upstream source.";
      };
      artifacts = mkOption {
        type = types.attrsOf artifactType;
        default = {};
        description = "Artifacts keyed by identifier.";
      };
    };
  });

  # Normalize plain manifest data through the type, for tests and helpers.
  evalManifest = name: data:
    (lib.evalModules {
      modules = [
        {
          options.manifest = mkOption {type = manifestType;};
          config.manifest = {inherit name;} // data;
        }
      ];
    }).config.manifest;

  isSri = h: h != null && lib.hasPrefix "sha256-" h;

  # License semantics follow nixpkgs: a license is free when its `free`
  # attribute is true (nixpkgs counts unfreeRedistributableFirmware as
  # free) and redistributable when `redistributable` is true.
  nixpkgsFree = l: builtins.isAttrs l && (l.free or true);
  nixpkgsRedistributable = l: builtins.isAttrs l && (l.redistributable or (l.free or true));
  # Nixpkgs permits some non-free firmware in allowUnfree=false profiles.
  # That profile convention does not make a vendor artifact R0/FOSS.
  fossLicense = l:
    builtins.isAttrs l
    && l ? spdxId
    && nixpkgsFree l
    && lib.any (known: (known.spdxId or null) == l.spdxId && nixpkgsFree known) (builtins.attrValues lib.licenses);

  # nixpkgs configuration of every free profile (D7): nixpkgs' own default.
  freeNixpkgsConfig = {allowUnfree = false;};

  artifactErrors = manifest: id: a: let
    at = "${manifest.name}.${id}";
    err = cond: msg: lib.optional cond "${at}: ${msg}";
    r = a.redistribution;
  in
    if a.status == "blocked"
    then err (a.blockedReason == null) "blocked artifacts must name a blockedReason"
    else
      err (a.license == null) "license is required"
      ++ err (a.license != null && !(a.license ? free)) "license must state `free`"
      ++ err (!(isSri a.sha256)) "sha256 must be an SRI sha256 hash"
      ++ err (a.size == null) "size is required"
      ++ err (!lib.all isSri a.derivedHashes) "derivedHashes must be SRI sha256 hashes"
      ++ err (a.class != "R0" && a.evidence == null) "non-free artifacts require license evidence"
      ++ err (a.class == "R0" && a.license != null && !(fossLicense a.license)) "R0 requires a recognized free SPDX license"
      ++ err (a.class == "R1" && a.license != null && !(nixpkgsRedistributable a.license)) "R1 requires a license nixpkgs marks redistributable"
      ++ err (a.class != "R2" && a.url == null) "${a.class} requires a pinned url"
      ++ err (a.class == "R1" && !r.file) "R1 requires redistribution.file"
      ++ err (a.class == "R1" && a.notices == []) "R1 requires at least one license or notice file"
      ++ err (a.class == "R2" && a.instructions == null) "R2 requires import instructions"
      ++ err (a.class == "R2" && (r.file || r.image || r.cache)) "R2 artifacts cannot be publicly redistributable"
      ++ err (r.cache && !r.file) "redistribution.cache requires redistribution.file";

  manifestErrors = manifest: lib.concatLists (lib.mapAttrsToList (artifactErrors manifest) manifest.artifacts);

  artifactName = manifest: id: "${manifest.name}-${id}";

  adopted = manifest: lib.filterAttrs (_: a: a.status == "adopted") manifest.artifacts;

  namesWhere = pred: manifests:
    lib.concatMap (m:
      lib.mapAttrsToList (id: _: artifactName m id)
      (lib.filterAttrs (_: pred) (adopted m)))
    manifests;

  # Package names that need an unfree allowance under nixpkgs semantics.
  unfreePackages = namesWhere (a: !(nixpkgsFree a.license));

  # Package names safe for the public cache: adopted R1 cleared for `cache`.
  cacheablePackages = namesWhere (a: a.class == "R1" && a.redistribution.cache);

  # Hashes of files, adopted or blocked, that must never reach the public cache.
  nonCacheableHashes = manifests:
    lib.concatMap (m:
      lib.concatLists (lib.mapAttrsToList (_: a:
        lib.optionals (a.class != "R0" && !(a.class == "R1" && a.redistribution.cache))
        (lib.filter (h: h != null) ([a.sha256] ++ a.derivedHashes)))
      m.artifacts))
    manifests;

  namePredicate = names: pkg: builtins.elem (lib.getName pkg) names;

  hex = hash:
    builtins.convertHash {
      inherit hash;
      toHashFormat = "base16";
    };

  # Build one artifact. `fetch` ({url, hash, name} -> path) replaces the
  # downloader for the file and its notices, so tests can supply content
  # without network access; the size and hash are checked either way.
  mkArtifact = {
    pkgs,
    manifest,
    id,
    fetch ? null,
  }: let
    a = manifest.artifacts.${id} or (throw "${manifest.name}: no artifact ${id}");
    pname = artifactName manifest id;
    errors = artifactErrors manifest id a;
    fileName = baseNameOf a.path;
    inherit (a) license;
    fetchFile =
      if fetch != null
      then fetch
      else
        {
          url,
          hash,
          name,
        }:
          pkgs.fetchurl {inherit url hash name;};
    src =
      if a.class == "R2" && fetch == null
      then
        # The store name stays the file name the operator adds; pname lets
        # the generated unfree predicate cover the source too.
        (pkgs.requireFile {
          name = fileName;
          hash = a.sha256;
          message = ''
            ${pname} is operator-supplied (class R2) and cannot be downloaded
            automatically.

            ${a.instructions}

            Then add it to the Nix store:
              nix-store --add-fixed sha256 ${fileName}
          '';
        }).overrideAttrs (old: {
          inherit pname;
          meta = (old.meta or {}) // {inherit license;};
        })
      else
        fetchFile {
          inherit (a) url;
          hash = a.sha256;
          name = fileName;
        };
    # Query strings (e.g. cgit's `?id=`) are not part of the file name and
    # are not valid in FAT boot partitions.
    noticeName = url: lib.head (lib.splitString "?" (baseNameOf url));
    notices =
      lib.imap0 (i: n: {
        name = "${toString i}-${noticeName n.url}";
        file = fetchFile {
          inherit (n) url;
          hash = n.sha256;
          name = "${pname}-notice-${toString i}";
        };
      })
      a.notices;
  in
    if a.status == "blocked"
    then throw "${manifest.name}.${id} is blocked (${a.blockedReason}) and cannot be packaged"
    else if errors != []
    then throw "invalid release manifest:\n${lib.concatStringsSep "\n" errors}"
    else
      pkgs.stdenvNoCC.mkDerivation {
        inherit pname;
        inherit (manifest) version;
        dontUnpack = true;
        dontFixup = true;
        allowSubstitutes = a.class != "R2";
        preferLocalBuild = a.class == "R2";
        installPhase = ''
          runHook preInstall
          test "$(stat -c %s ${src})" = ${toString a.size} \
            || { echo "${pname}: size differs from the release manifest" >&2; exit 1; }
          echo "${hex a.sha256}  ${src}" | sha256sum -c --quiet \
            || { echo "${pname}: sha256 differs from the release manifest" >&2; exit 1; }
          install -Dm444 ${src} "$out/${a.path}"
          ${lib.concatMapStrings (n: ''
              install -Dm444 ${n.file} "$out/share/licenses/${pname}/${n.name}"
            '')
            notices}
          runHook postInstall
        '';
        passthru.manifestEntry = {
          manifest = manifest.name;
          inherit id;
          inherit (manifest) provider;
          inherit (a) class layer load path sha256 derivedHashes features;
          redistribution = {inherit (a.redistribution) file image cache private;};
        };
        meta = {
          description = "${id} from ${manifest.source}";
          inherit license;
          sourceProvenance =
            if a.load == "userspace"
            then [lib.sourceTypes.binaryNativeCode]
            else [lib.sourceTypes.binaryFirmware];
        };
      };

  # Label a kernel with its provider (D3). passthru is not part of the
  # derivation, so labelling does not rebuild the kernel.
  withProvider = provider: kernel:
    kernel.overrideAttrs (old: {
      passthru = (old.passthru or {}) // {inherit provider;};
    });

  # Resource claims: a list of { resource, owner }. A resource claimed by
  # more than one owner is a conflict.
  claimConflicts = claims:
    lib.concatLists (lib.mapAttrsToList (resource: cs: let
      owners = lib.sort lib.lessThan (lib.unique (map (c: c.owner) cs));
    in
      lib.optional (builtins.length owners > 1)
      "resource ${resource} is claimed by ${lib.concatStringsSep ", " owners}")
    (lib.groupBy (c: c.resource) claims));

  # Public push set (D8 gate 1). Every manifest artifact a published
  # configuration installs must be cleared for `cache`, and for `image`
  # when images are published; cache-cleared R1 artifacts are added
  # explicitly. Anything else fails evaluation.
  mkPublicPushSet = {
    pkgs,
    name,
    fixture,
    publish,
    manifests,
  }: let
    imagePublished = lib.any (attr: attr != "toplevel") publish;
    violations = lib.concatMap (p: let
      e = p.manifestEntry;
      missing =
        lib.optional (!e.redistribution.cache) "cache"
        ++ lib.optional (imagePublished && !e.redistribution.image) "image";
    in
      lib.optional (e.class != "R0" && missing != [])
      "${e.manifest}.${e.id} is not cleared for ${lib.concatStringsSep " or " missing}")
    fixture.config.hardware.boards.artifacts;
    artifacts = lib.concatMap (m:
      lib.mapAttrsToList (id: _:
        mkArtifact {
          inherit pkgs id;
          manifest = m;
        })
      (lib.filterAttrs (_: a: a.status == "adopted" && a.class == "R1" && a.redistribution.cache) m.artifacts))
    manifests;
  in
    if violations != []
    then throw "${name}: refusing to build the public push set:\n${lib.concatStringsSep "\n" violations}"
    else
      pkgs.linkFarmFromDrvs name
      (map (attr: fixture.config.system.build.${attr}) publish ++ artifacts);

  # Pre-push scan (D8 gate 2). Hashes every regular file in the closure
  # of the given store paths and fails if any matches a file the
  # manifests do not clear for the public cache. `--closure-file F` reads
  # store paths from F (e.g. closureInfo's store-paths) instead of asking
  # the Nix store for the closure.
  mkCacheScan = {
    pkgs,
    hashes,
  }: let
    deny = pkgs.writeText "nixos-boards-non-cacheable-sha256" (lib.concatMapStrings (h: "${hex h}\n") (lib.unique hashes));
  in
    pkgs.writeShellApplication {
      name = "nixos-boards-cache-scan";
      runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.gnugrep];
      text = ''
        usage() {
          echo "usage: nixos-boards-cache-scan STORE-PATH... | --closure-file FILE" >&2
          exit 2
        }
        refuse() {
          echo "Refusing to publish: $1" >&2
          exit 2
        }
        # Only canonical top-level store paths: no nested, dot or relative
        # paths, which would let a list skip the rest of a store path, and
        # no reliance on Nix normalising a path to its store root.
        canonical='^${builtins.storeDir}/[0-9a-z]{32}-[A-Za-z0-9+_?=-][A-Za-z0-9+._?=-]*$'
        roots() {
          for p in "$@"; do
            [[ "$p" =~ $canonical ]] || refuse "$p is not a top-level store path"
            [ -e "$p" ] || [ -L "$p" ] || refuse "$p does not exist"
          done
          # Existing is not enough: every path must be registered in the store.
          nix-store --check-validity "$@" || refuse "the closure lists paths that are not valid in the Nix store"
        }
        # Only the Nix store can say whether a path is registered and what its
        # closure is; without it nothing can be validated.
        command -v nix-store >/dev/null || refuse "nix-store is needed to validate store paths"
        closure=$(mktemp)
        hashes=$(mktemp)
        trap 'rm -f "$closure" "$closure".* "$hashes"' EXIT
        # The closure must be complete: a failed query, an empty closure or a
        # path that is not in the store fails the scan instead of passing it.
        if [ "''${1:-}" = --closure-file ]; then
          [ "$#" -eq 2 ] || usage
          [ -s "$2" ] || refuse "closure file $2 is missing or empty"
          cp "$2" "$closure"
        else
          [ "$#" -gt 0 ] || usage
          roots "$@"
          nix-store --query --requisites "$@" > "$closure" || refuse "could not query the closure of $*"
          # The store's answer must include every root it was asked about.
          for root in "$@"; do
            grep -qxF -- "$root" "$closure" || refuse "the queried closure does not include $root"
          done
        fi
        mapfile -t paths < "$closure"
        [ "''${#paths[@]}" -gt 0 ] || refuse "the closure is empty"
        roots "''${paths[@]}"
        # A closure file must be complete: every reference of every listed
        # path must be listed too.
        if [ "''${1:-}" = --closure-file ]; then
          nix-store --query --requisites "''${paths[@]}" > "$closure.full" ||
            refuse "could not query the closure of the listed paths"
          [ -s "$closure.full" ] || refuse "the store returned no closure for the listed paths"
          sort -u "$closure" > "$closure.listed"
          sort -u "$closure.full" > "$closure.needed"
          # The list must be exactly the closure the store reports.
          comm -13 "$closure.listed" "$closure.needed" > "$closure.missing"
          [ ! -s "$closure.missing" ] || refuse "the closure file omits $(wc -l < "$closure.missing") referenced store paths"
          comm -23 "$closure.listed" "$closure.needed" > "$closure.extra"
          [ ! -s "$closure.extra" ] || refuse "the store does not report $(wc -l < "$closure.extra") listed paths in their closure"
        fi
        for p in "''${paths[@]}"; do
          find "$p" -type f -print0 | xargs -0 -r sha256sum >> "$hashes"
        done
        # grep exits 1 when nothing matches; any other failure aborts.
        matches=$(grep -F -f ${deny} "$hashes") || [ "$?" -eq 1 ]
        if [ -n "$matches" ]; then
          echo "Refusing to publish: these files match artifacts not cleared for the public cache:" >&2
          echo "$matches" >&2
          exit 1
        fi
        echo "No non-cacheable artifacts in ''${#paths[@]} store paths."
      '';
    };

  # Generated wiki pages for one board (D10): hardware matrix, firmware
  # table and the free-versus-non-free gap table. Pure function of the
  # registry entry and its manifests.
  generatedHeader = "<!-- Generated by `nix run .#write-docs` from release manifests and the board registry; do not edit. -->\n\n";

  docPages = {
    page,
    manifests,
    functions,
    haveHardware,
  }: let
    cell = x: lib.replaceStrings ["|" "\n"] ["\\|" " "] (toString x);
    row = cells: "| ${lib.concatMapStringsSep " | " cell cells} |\n";
    table = header: rows:
      row header
      + row (map (_: "---") header)
      + lib.concatMapStrings row rows;
    licenseName = l: l.spdxId or l.shortName or "unknown";
    artifacts = lib.concatMap (m:
      lib.mapAttrsToList (id: a:
        a
        // {
          inherit id;
          manifest = m.name;
        })
      m.artifacts)
    manifests;
    needs = feature: lib.filter (a: builtins.elem feature a.features) artifacts;
    availability = fn: let
      as = lib.concatMap needs fn.features;
      blocked = lib.filter (a: a.status == "blocked") as;
    in
      if blocked != []
      then "blocked: ${lib.concatStringsSep ", " (lib.unique (map (a: a.blockedReason) blocked))}"
      else if lib.any (a: !(nixpkgsFree a.license)) as
      then "full"
      else "free";
    forms = r: lib.concatStringsSep ", " (lib.filter (f: r.${f}) ["file" "image" "cache" "private"]);
    statusText = fn:
      if fn.status == "blocked" && fn.reason != null
      then "blocked: ${fn.reason}"
      else fn.status;
    # Gaps follow nixpkgs: what allowUnfree = false excludes, plus blocked.
    gaps = lib.filter (a: a.status == "blocked" || !(nixpkgsFree a.license)) artifacts;
  in {
    "${page}-Hardware-Matrix.md" =
      generatedHeader
      + "# ${page} hardware matrix\n\n"
      + "Maintainers ${
        if haveHardware
        then "have"
        else "do not have"
      } this board, so ${
        if haveHardware
        then "functions can be verified on hardware"
        else "functions cannot be verified on hardware yet"
      }.\n\n"
      + "*Profile* is the profile that provides the function: `free`, `full` (needs non-free artifacts) or `blocked`. See [Free vs non-free](${page}-Free-vs-NonFree).\n\n"
      + table ["Function" "Status" "Profile" "Features" "Evidence"]
      (lib.mapAttrsToList (name: fn: [
          name
          (statusText fn)
          (availability fn)
          (lib.concatStringsSep ", " fn.features)
          (
            if fn.evidence == null
            then ""
            else "[evidence](${fn.evidence})"
          )
        ])
        functions);

    "${page}-Firmware.md" =
      generatedHeader
      + "# ${page} firmware\n\n"
      + (
        if lib.all (m: m.artifacts == {}) manifests
        then "This board uses no artifacts from release manifests. The firmware it needs comes from nixpkgs or an upstream flake; see [${page}](${page}).\n"
        else "Every artifact below is pinned in a release manifest. Classes: R0 free, R1 redistributable, R2 operator-supplied; see [Glossary](Glossary).\n"
      )
      + lib.concatMapStrings (m:
        "\n## ${m.name}\n\nProvider `${m.provider}`, version ${m.version}: ${m.source}.\n\n"
        + table ["Artifact" "Status" "Class" "License" "Layer" "Load" "Redistribution" "Evidence"]
        (lib.mapAttrsToList (id: a: [
            "`${id}`"
            (
              if a.status == "blocked"
              then "blocked: ${a.blockedReason}"
              else "adopted"
            )
            a.class
            (
              if a.license == null
              then ""
              else licenseName a.license
            )
            a.layer
            a.load
            (forms a.redistribution)
            (
              if a.evidence == null
              then ""
              else "[${a.evidence.location}](${a.evidence.url}), ${a.evidence.retrieved}"
            )
          ])
          m.artifacts))
      manifests;

    "${page}-Free-vs-NonFree.md" =
      generatedHeader
      + "# ${page}: free and full profiles\n\n"
      + (
        if gaps == []
        then "The free profile provides every supported function.\n"
        else
          "These features need artifacts that nixpkgs does not allow with `allowUnfree = false`, so only the full profile includes them. Blocked artifacts are not packaged in any profile.\n"
          + lib.concatMapStrings (layer: let
            here = lib.filter (a: a.layer == layer) gaps;
          in
            lib.optionalString (here != []) (
              "\n## ${layer}\n\n"
              + table ["Features" "Artifact" "Class" "Available in"]
              (map (a: [
                  (lib.concatStringsSep ", " a.features)
                  "`${a.manifest}.${a.id}`"
                  a.class
                  (
                    if a.status == "blocked"
                    then "blocked: ${a.blockedReason}"
                    else "full"
                  )
                ])
                here)
            ))
          layers
      );
  };

  # Guarded, operator-run firmware writer (D4). `write` is the body of a
  # shell function that receives the verified firmware path as $1.
  mkFlashTool = {
    pkgs,
    board,
    firmware,
    target,
    recovery,
    write,
    runtimeInputs ? [],
  }: let
    entry = firmware.manifestEntry;
  in
    pkgs.writeShellApplication {
      name = "${board}-flash-firmware";
      runtimeInputs = [pkgs.coreutils] ++ runtimeInputs;
      text = ''
        if [ ! -t 0 ] || [ ! -t 1 ]; then
          echo "${board}-flash-firmware: refusing to run without an interactive terminal" >&2
          exit 2
        fi
        image=${firmware}/${entry.path}
        cat <<'EOF'
        Board:     ${board}
        Target:    ${target}
        Firmware:  ${entry.manifest} ${firmware.version} (${entry.id})
        sha256:    ${entry.sha256}

        Recovery if this fails:
        ${recovery}
        EOF
        echo "${hex entry.sha256}  $image" | sha256sum -c --quiet \
          || { echo "firmware does not match the release manifest" >&2; exit 1; }
        printf 'Type the board name (%s) to write the firmware: ' ${lib.escapeShellArg board}
        read -r answer
        if [ "$answer" != ${lib.escapeShellArg board} ]; then
          echo "aborted; nothing was written" >&2
          exit 1
        fi
        write() {
        ${write}
        }
        write "$image"
      '';
    };
in {
  types = {
    artifact = artifactType;
    manifest = manifestType;
  };
  inherit
    classes
    layers
    loads
    evalManifest
    manifestErrors
    artifactName
    unfreePackages
    cacheablePackages
    nonCacheableHashes
    namePredicate
    mkArtifact
    freeNixpkgsConfig
    withProvider
    claimConflicts
    mkFlashTool
    mkPublicPushSet
    mkCacheScan
    generatedHeader
    docPages
    ;
}
