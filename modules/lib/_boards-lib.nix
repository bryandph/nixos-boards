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
    private = "The license permits internal copies in the licensee's private binary cache, served only to the licensee's own systems.";
    build = "The license permits internal copies on the licensee's own build machines while building. Implied by `file` and `private`.";
  };

  # Internal build copies are permitted when granted explicitly or implied
  # by a broader grant (redistribution or the private cache).
  buildPermitted = r: r.build || r.file || r.private;

  redistributionType = types.submodule {
    options = lib.mapAttrs (_: description:
      mkOption {
        type = types.bool;
        default = false;
        inherit description;
      })
    redistributionDescriptions;
  };

  # A recorded risk interpretation is not a copyright-holder grant and never
  # supplies redistribution forms. It permits only controlled internal builds.
  internalUseType = types.submodule {
    options = {
      accepted = mkOption {
        type = types.bool;
        default = false;
        description = "The operator explicitly accepted this bounded interpretation.";
      };
      target = mkOption {
        type = types.str;
        description = "Device/use boundary of the interpretation.";
      };
      rationale = mkOption {
        type = types.str;
        description = "Evidence-based reason for accepting internal use; not an express vendor grant.";
      };
      uncertainty = mkOption {
        type = types.str;
        description = "Unresolved rights uncertainty retained by the operator.";
      };
      evidence = mkOption {
        type = evidenceType;
        description = "Pinned source evidence supporting the interpretation, not a grant.";
      };
    };
  };
  internalUseOption = mkOption {
    type = types.nullOr internalUseType;
    default = null;
    description = "Explicit operator-accepted internal-build interpretation, separate from license grants; no cache or redistribution permission.";
  };
  internalBuildPermitted = entry:
    buildPermitted entry.redistribution
    || (entry.internalUse != null && entry.internalUse.accepted);
  internalUseErrors = at: entry: let
    i = entry.internalUse;
    r = entry.redistribution;
    err = cond: msg: lib.optional cond "${at}: ${msg}";
  in
    lib.optionals (i != null) (
      err (!i.accepted) "internal-use interpretation requires explicit operator acceptance"
      ++ err (entry.class != "R2") "internal-use interpretation is restricted to R2"
      ++ err (entry.license != null && nixpkgsRedistributable entry.license) "internal-use interpretation must not label the license redistributable"
      ++ err (lib.any (form: r.${form}) ["file" "image" "cache" "private" "build"]) "internal-use interpretation cannot supply or accompany redistribution grants"
      ++ err (lib.any (text: builtins.match "[[:space:]]*" text != null) [i.target i.rationale i.uncertainty i.evidence.url i.evidence.location]) "internal-use interpretation requires nonblank target, rationale, uncertainty and source evidence"
    );
  internalUseText = i: ''
    Operator-accepted internal-build interpretation (NOT an express vendor grant)
    Target: ${i.target}
    Rationale: ${i.rationale}
    Uncertainty: ${i.uncertainty}
    Evidence: ${i.evidence.url}
    Location: ${i.evidence.location}
    Retrieved: ${i.evidence.retrieved}
    Controlled internal builders only. No standalone file, image, public cache
    or private cache permission. Derived output caching remains denied pending
    a separate rights assessment and approved policy change.
  '';

  artifactType = types.submodule {
    options = {
      internalUse = internalUseOption;
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

  # A package built from artifacts or from non-free sources (e.g. an SDK
  # build). It carries its own license, evidence and redistribution forms,
  # and its class is at least as restrictive as every artifact it uses.
  builtType = types.submodule {
    options = {
      notices = mkOption {
        type = types.listOf fileType;
        default = [];
        description = "Pinned license/notice files installed with every package output.";
      };
      derivedHashes = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Verified SRI hashes of derived regular-file forms. Deny evidence only, not complete provenance or cache admission.";
      };
      provider = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Explicit package provider override, e.g. any for a runtime shared by this board's kernel providers. Null inherits the release provider.";
      };
      internalUse = internalUseOption;
      class = mkOption {
        type = types.enum classes;
        description = "Class of the built package; at least the strictest class of `from`.";
      };
      from = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Identifiers of the manifest's artifacts the package is built from.";
      };
      sources = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Other pinned sources and their licenses, for documentation, e.g. `TI vision_apps (TI Text File License)`.";
      };
      license = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "License of the built package, as for artifacts.";
      };
      evidence = mkOption {
        type = types.nullOr evidenceType;
        default = null;
        description = "Where the license grant for the built package was established.";
      };
      redistribution = mkOption {
        type = redistributionType;
        default = {};
        description = "Redistribution forms the licenses permit for the built package.";
      };
      layer = mkOption {
        type = types.enum layers;
        description = "Support layer the package belongs to.";
      };
      load = mkOption {
        type = types.enum loads;
        description = "How the package reaches the hardware.";
      };
      features = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Features (or functions) the package enables.";
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
      built = mkOption {
        type = types.attrsOf builtType;
        default = {};
        description = "Packages built from artifacts or non-free sources, keyed by identifier.";
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
      internalUseErrors at a
      ++ err (a.license == null) "license is required"
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

  classRank = class: lib.lists.findFirstIndex (c: c == class) 0 classes;

  builtErrors = manifest: id: b: let
    at = "${manifest.name}.${id}";
    err = cond: msg: lib.optional cond "${at}: ${msg}";
    r = b.redistribution;
    inputs = map (i: manifest.artifacts.${i} or null) b.from;
  in
    internalUseErrors at b
    ++ err (manifest.artifacts ? ${id}) "an artifact and a built package share the identifier"
    ++ lib.concatMap (i: err (!(manifest.artifacts ? ${i})) "built from unknown artifact ${i}") b.from
    ++ lib.concatMap (i: err ((manifest.artifacts.${i}.status or "") == "blocked") "built from blocked artifact ${i}") b.from
    ++ err (lib.any (a: a != null && classRank a.class > classRank b.class) inputs) "class ${b.class} is less restrictive than an artifact it is built from"
    ++ lib.concatMap (form:
      err (r.${form} && lib.any (a: a != null && a.class != "R0" && !a.redistribution.${form}) inputs)
      "redistribution.${form} is not permitted by every artifact it is built from") ["file" "image" "cache" "private"]
    ++ err (buildPermitted r && lib.any (a: a != null && a.class != "R0" && !(buildPermitted a.redistribution)) inputs)
    "licensed internal build permission is not granted by every artifact it is built from; interpretation is not a license grant"
    ++ err (internalBuildPermitted b && lib.any (a: a != null && a.class != "R0" && !(internalBuildPermitted a)) inputs)
    "internal build copies are not permitted by every artifact it is built from"
    ++ err (!lib.all isSri b.derivedHashes) "derivedHashes must be SRI sha256 hashes"
    ++ err (b.license == null) "license is required"
    ++ err (b.license != null && !(b.license ? free)) "license must state `free`"
    ++ err (b.class != "R0" && b.evidence == null) "non-free built packages require license evidence"
    ++ err (b.class == "R0" && b.license != null && !(fossLicense b.license)) "R0 requires a recognized free SPDX license"
    ++ err (b.class == "R1" && b.license != null && !(nixpkgsRedistributable b.license)) "R1 requires a license nixpkgs marks redistributable"
    ++ err (b.class == "R2" && (r.file || r.image || r.cache)) "R2 packages cannot be publicly redistributable"
    ++ err (r.cache && !r.file) "redistribution.cache requires redistribution.file";

  manifestErrors = manifest:
    lib.concatLists (lib.mapAttrsToList (artifactErrors manifest) manifest.artifacts)
    ++ lib.concatLists (lib.mapAttrsToList (builtErrors manifest) manifest.built);

  artifactName = manifest: id: "${manifest.name}-${id}";

  adopted = manifest: lib.filterAttrs (_: a: a.status == "adopted") manifest.artifacts;

  # Adopted artifacts and built packages.
  namesWhere = pred: manifests:
    lib.concatMap (m:
      lib.mapAttrsToList (id: _: artifactName m id)
      (lib.filterAttrs (_: pred) (adopted m // m.built)))
    manifests;

  # Package names that need an unfree allowance under nixpkgs semantics.
  unfreePackages = namesWhere (a: !(nixpkgsFree a.license));

  # Package names safe for the public cache: adopted R1 artifacts and built
  # packages cleared for `cache`.
  cacheablePackages = namesWhere (a: a.class == "R1" && a.redistribution.cache);

  # Hashes of files, adopted or blocked, that must never reach the public cache.
  nonCacheableHashes = manifests:
    lib.concatMap (m:
      lib.concatLists (lib.mapAttrsToList (_: a:
        lib.optionals (a.class != "R0" && !(a.class == "R1" && a.redistribution.cache))
        (lib.filter (h: h != null) ([a.sha256] ++ a.derivedHashes)))
      m.artifacts)
      ++ lib.concatLists (lib.mapAttrsToList (_: b:
        lib.optionals (b.class != "R0" && !(b.class == "R1" && b.redistribution.cache)) b.derivedHashes)
      m.built))
    manifests;

  # Hashes of files, adopted or blocked, not cleared for the private cache.
  nonPrivateHashes = manifests:
    lib.concatMap (m:
      lib.concatLists (lib.mapAttrsToList (_: a:
        lib.optionals (a.class != "R0" && !a.redistribution.private)
        (lib.filter (h: h != null) ([a.sha256] ++ a.derivedHashes)))
      m.artifacts)
      ++ lib.concatLists (lib.mapAttrsToList (_: b:
        lib.optionals (b.class != "R0" && !b.redistribution.private) b.derivedHashes)
      m.built))
    manifests;

  # Additional current-generation DENY evidence for a consumer. This is not
  # provenance admission and cannot identify copied/unknown/historical forms.
  artifactOutputIdentities = packages:
    lib.concatMap (p:
      if !(p ? manifestEntry)
      then throw "artifactOutputIdentities requires registered manifest packages"
      else
        map (output: {
          inherit output;
          path = p.${output}.outPath;
          drv = p.drvPath;
          inherit (p.manifestEntry) manifest id class provider redistribution;
        })
        p.outputs)
    packages;

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
        installPhase =
          ''
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
          ''
          + lib.optionalString (a.internalUse != null) ''
            mkdir -p "$out/share/licenses/${pname}"
            printf '%s' ${lib.escapeShellArg (internalUseText a.internalUse)} > "$out/share/licenses/${pname}/internal-use-interpretation.txt"
          '';
        passthru.manifestEntry = {
          manifest = manifest.name;
          inherit id;
          inherit (manifest) provider;
          inherit (a) class layer load path sha256 derivedHashes features internalUse;
          internalBuild = internalBuildPermitted a;
          redistribution = {
            inherit (a.redistribution) file image cache private;
            build = buildPermitted a.redistribution;
          };
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

  # Register a package built from manifest inputs. The package keeps its
  # derivation; its name must be `<manifest>-<id>`, and its license and
  # manifest entry come from the release manifest, so the generated unfree
  # lists and the publication gates cover it like an artifact.
  mkBuilt = {
    manifest,
    id,
    package,
    pkgs ? null,
  }: let
    b = manifest.built.${id} or (throw "${manifest.name}: no built package ${id}");
    name = artifactName manifest id;
    errors = builtErrors manifest id b;
  in
    if errors != []
    then throw "invalid release manifest:\n${lib.concatStringsSep "\n" errors}"
    else if lib.getName package != name
    then throw "${manifest.name}.${id}: the package is named ${lib.getName package}, not ${name}"
    else if b.notices != [] && pkgs == null
    then throw "${manifest.name}.${id}: mkBuilt needs pkgs to fetch pinned notices"
    else if
      (b.internalUse != null || b.notices != [])
      && !(package.drvAttrs ? buildCommand)
      && package.drvAttrs ? installPhase
      && !(lib.hasInfix "runHook postInstall" package.drvAttrs.installPhase)
    then throw "${manifest.name}.${id}: internal-use notice requires a custom installPhase to runHook postInstall"
    else
      package.overrideAttrs (old: let
        files =
          lib.imap0 (i: n: {
            name = "${toString i}-${baseNameOf n.url}";
            file = pkgs.fetchurl {
              inherit (n) url;
              hash = n.sha256;
            };
          })
          b.notices;
        notice = lib.optionalString (b.internalUse != null || b.notices != []) ''
          for output in ${lib.escapeShellArgs (old.outputs or ["out"])}; do
            outputPath="''${!output}"
            mkdir -p "$outputPath/share/licenses/${name}"
            ${lib.optionalString (b.internalUse != null) ''
            printf '%s' ${lib.escapeShellArg (internalUseText b.internalUse)} > "$outputPath/share/licenses/${name}/internal-use-interpretation.txt"
          ''}
            ${lib.concatMapStrings (n: ''
              install -m444 ${n.file} "$outputPath/share/licenses/${name}/${n.name}"
            '')
            files}
          done
        '';
      in {
        # runCommand uses buildCommand rather than the standard install phase.
        ${
          if b.internalUse == null && b.notices == []
          then null
          else if old ? buildCommand
          then "buildCommand"
          else "postInstall"
        } =
          (
            if old ? buildCommand
            then old.buildCommand
            else old.postInstall or ""
          )
          + (
            if notice == ""
            then ""
            else "\n" + notice
          );
        passthru =
          (old.passthru or {})
          // {
            manifestEntry = {
              manifest = manifest.name;
              inherit id;
              provider =
                if b.provider == null
                then manifest.provider
                else b.provider;
              inherit (b) class layer load features from internalUse notices;
              internalBuild = internalBuildPermitted b;
              built = true;
              path = null;
              sha256 = null;
              derivedHashes = b.derivedHashes;
              redistribution = {
                inherit (b.redistribution) file image cache private;
                build = buildPermitted b.redistribution;
              };
            };
          };
        meta = (old.meta or {}) // {inherit (b) license;};
      });

  # Operator-run import of R2 artifacts (D6). Nothing is downloaded until
  # the operator passes --accept-license after reading the terms; each file
  # is checked against the manifest before it is added to the store.
  mkImportTool = {
    pkgs,
    name,
    manifests,
  }: let
    entries = lib.concatMap (m:
      lib.mapAttrsToList (id: a: {
        inherit id a;
        manifest = m.name;
      }) (lib.filterAttrs (_: a: a.class == "R2") (adopted m)))
    manifests;
    record = e:
      lib.concatStringsSep "|" [
        "${e.manifest}.${e.id}"
        (baseNameOf e.a.path)
        (hex e.a.sha256)
        (toString e.a.size)
        (
          if e.a.url == null
          then "-"
          else e.a.url
        )
        (
          if e.a.evidence == null
          then "-"
          else e.a.evidence.url
        )
      ];
  in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.nix];
      text =
        lib.concatMapStrings (e:
          lib.optionalString (e.a.internalUse != null) ''
            printf '%s\n' ${lib.escapeShellArg ("${e.manifest}.${e.id}:\n" + internalUseText e.a.internalUse)}
          '')
        entries
        + ''
          accept=0
          case "''${1:-}" in
            --accept-license) accept=1 ;;
            "") ;;
            *)
              echo "usage: ${name} [--accept-license]" >&2
              exit 2
              ;;
          esac
          records=(
          ${lib.concatMapStringsSep "\n" (e: "  ${lib.escapeShellArg (record e)}") entries}
          )
          status=0
          work=$(mktemp -d)
          trap 'rm -rf "$work"' EXIT
          for entry in "''${records[@]}"; do
            IFS='|' read -r label file hash size url terms <<< "$entry"
            path=$(nix-store --print-fixed-path sha256 "$hash" "$file")
            if nix-store --check-validity "$path" 2>/dev/null; then
              echo "$label: already imported ($path)"
              continue
            fi
            echo "$label: $file"
            echo "  terms: $terms"
            if [ "$url" = "-" ]; then
              echo "  obtain it as described on the board's firmware page, then: nix-store --add-fixed sha256 $file"
              status=1
              continue
            fi
            echo "  source: $url"
            if [ "$accept" -ne 1 ]; then
              status=1
              continue
            fi
            curl -fL --retry 3 -o "$work/$file" "$url"
            test "$(stat -c %s "$work/$file")" = "$size" \
              || { echo "$label: size differs from the release manifest" >&2; exit 1; }
            echo "$hash  $work/$file" | sha256sum -c --quiet \
              || { echo "$label: sha256 differs from the release manifest" >&2; exit 1; }
            nix-store --add-fixed sha256 "$work/$file"
            rm -f "$work/$file"
          done
          if [ "$accept" -ne 1 ] && [ "$status" -ne 0 ]; then
            echo "Review the terms above, then rerun with --accept-license to download and import." >&2
          fi
          exit "$status"
        '';
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
    lane ? "public",
  }: let
    name =
      if lane == "public"
      then "nixos-boards-cache-scan"
      else "nixos-boards-${lane}-cache-scan";
    deny = pkgs.writeText "${name}-deny-sha256" (lib.concatMapStrings (h: "${hex h}\n") (lib.unique hashes));
  in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.gnugrep];
      text = ''
        usage() {
          echo "usage: ${name} STORE-PATH... | --closure-file FILE" >&2
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
          echo "Refusing to publish: these files match artifacts not cleared for the ${lane} cache:" >&2
          echo "$matches" >&2
          exit 1
        fi
        echo "No artifacts barred from the ${lane} cache in ''${#paths[@]} store paths."
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
      (m.artifacts
        // lib.mapAttrs (_: b:
          b
          // {
            status = "adopted";
            blockedReason = null;
          })
        m.built))
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
    forms = r:
      lib.concatStringsSep ", " (lib.filter (f: r.${f}) ["file" "image" "cache" "private"]
        ++ lib.optional (r.build && !(buildPermitted (r // {build = false;}))) "build");
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
        if lib.all (m: m.artifacts == {} && m.built == {}) manifests
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
          m.artifacts)
        + lib.optionalString (m.built != {}) (
          "\n### Built packages\n\nPackages built from the artifacts above or from other pinned sources.\n\n"
          + lib.concatStrings (lib.mapAttrsToList (id: b: lib.optionalString (b.provider != null) "Package `${id}` uses provider `${b.provider}` rather than the release provider `${m.provider}`; this is a compatibility label, not a redistribution grant.\n\n") m.built)
          + table ["Package" "Class" "License" "Built from" "Layer" "Load" "Redistribution" "Evidence"]
          (lib.mapAttrsToList (id: b: [
              "`${id}`"
              b.class
              (
                if b.license == null
                then ""
                else licenseName b.license
              )
              (lib.concatStringsSep ", " (map (i: "`${i}`") b.from ++ b.sources))
              b.layer
              b.load
              (forms b.redistribution)
              (
                if b.evidence == null
                then ""
                else "[${b.evidence.location}](${b.evidence.url}), ${b.evidence.retrieved}"
              )
            ])
            m.built)
        ))
      manifests
      + (let
        interpretations = lib.filter (a: a.internalUse != null) artifacts;
      in
        lib.optionalString (interpretations != []) (
          "\n## Internal build interpretations\n\nThese are operator-accepted interpretations, not express vendor grants. Only controlled internal builders for the recorded target are permitted. Standalone helper publication and all affected output caching remain denied.\n\n"
          + lib.concatMapStringsSep "\n" (a: "### `${a.manifest}.${a.id}`\n\n" + internalUseText a.internalUse) interpretations
        ));

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
    nonPrivateHashes
    buildPermitted
    internalBuildPermitted
    internalUseText
    artifactOutputIdentities
    namePredicate
    mkArtifact
    freeNixpkgsConfig
    withProvider
    claimConflicts
    mkFlashTool
    mkBuilt
    mkImportTool
    mkPublicPushSet
    mkCacheScan
    generatedHeader
    docPages
    ;
}
