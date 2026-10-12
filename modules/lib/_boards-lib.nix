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
        description = "Provider label (D3), e.g. `mainline` or `radxa-7.0.11`.";
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

  # nixpkgs marks `unfreeRedistributableFirmware` as free so firmware builds
  # without allowUnfree; treat it as non-free here.
  isNonFree = l: !(l.free or true) || (l.shortName or "") == "unfreeRedistributableFirmware";

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
      ++ err (a.class == "R0" && a.license != null && isNonFree a.license) "R0 requires a free license"
      ++ err (a.class != "R0" && a.license != null && !(isNonFree a.license)) "${a.class} requires a non-free license"
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

  # Package names that need an unfree allowance: adopted R1 and R2.
  unfreePackages = namesWhere (a: a.class != "R0");

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
    # Non-free artifacts always need an unfree allowance, whatever nixpkgs
    # records for their license.
    license =
      if a.class == "R0"
      then a.license
      else a.license // {free = false;};
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
          meta = {inherit license;};
          hash = a.sha256;
          message = ''
            ${pname} is operator-supplied (class R2) and cannot be downloaded
            automatically.

            ${a.instructions}

            Then add it to the Nix store:
              nix-store --add-fixed sha256 ${fileName}
          '';
        }).overrideAttrs {inherit pname;}
      else
        fetchFile {
          inherit (a) url;
          hash = a.sha256;
          name = fileName;
        };
    notices =
      lib.imap0 (i: n: {
        name = "${toString i}-${baseNameOf n.url}";
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
            if a.class == "R0"
            then [lib.sourceTypes.fromSource]
            else if a.load == "userspace"
            then [lib.sourceTypes.binaryNativeCode]
            else [lib.sourceTypes.binaryFirmware];
        };
      };

  # Resource claims: a list of { resource, owner }. A resource claimed by
  # more than one owner is a conflict.
  claimConflicts = claims:
    lib.concatLists (lib.mapAttrsToList (resource: cs: let
      owners = lib.sort lib.lessThan (lib.unique (map (c: c.owner) cs));
    in
      lib.optional (builtins.length owners > 1)
      "resource ${resource} is claimed by ${lib.concatStringsSep ", " owners}")
    (lib.groupBy (c: c.resource) claims));

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
    claimConflicts
    mkFlashTool
    ;
}
