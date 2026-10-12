{
  config,
  inputs,
  lib,
  ...
}: let
  boardsLib = config.boards.lib;
  data = import ./_test/manifests.nix {inherit lib;};
  valid = boardsLib.evalManifest "test-board" data.valid;
  invalid = boardsLib.evalManifest "invalid" data.invalid;
  name = boardsLib.artifactName valid;
  sortedEq = a: b: lib.sort lib.lessThan a == lib.sort lib.lessThan b;
  failsToEval = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
  expect = cond: msg:
    if cond
    then true
    else throw "test failed: ${msg}";

  # Synthetic test board composition: one core and add-on features that
  # claim connector resources. Imports hardware-boards twice on purpose.
  testCore = {pkgs, ...}: {
    imports = [config.flake.modules.nixos.hardware-boards];
    nixpkgs.hostPlatform = "aarch64-linux";
    boot.kernelPackages = pkgs.linuxPackagesFor (boardsLib.withProvider "test-1.0" pkgs.linux);
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "ext4";
    };
    hardware.boards = {
      image.layoutVersion = 1;
      identity = {
        board = "test-board";
        vendor = "test";
        soc = "test-soc";
        bootChain = "board";
        provider = "test-1.0";
      };
      connectors.header = {
        standard = "rpi-40pin";
        bindings = {
          i2c = "&i2c1";
          uart = "&uart0";
        };
      };
    };
  };
  claim = owner: resources: {
    imports = [config.flake.modules.nixos.hardware-boards];
    hardware.boards.claims = map (resource: {inherit resource owner;}) resources;
  };
  boardAssertions = modules:
    map (a: a.message)
    (lib.filter (a: !a.assertion && lib.hasPrefix "hardware.boards" a.message)
      (inputs.nixpkgs.lib.nixosSystem {modules = [testCore] ++ modules;}).config.assertions);

  # Features of the synthetic board. `useArtifacts` installs manifest
  # artifacts the way real board features do.
  useArtifacts = ids: {pkgs, ...}: let
    packages = map (id:
      boardsLib.mkArtifact {
        inherit pkgs id;
        manifest = valid;
        fetch = testFetch pkgs;
      })
    ids;
  in {
    hardware.firmware = packages;
    hardware.boards.artifacts = packages;
  };
  testFetch = pkgs: {
    name,
    url,
    ...
  }:
    pkgs.writeText name
    data.contents.${
      if url == null
      then name
      else lib.head (lib.splitString "?" (baseNameOf url))
    };
  testEntry = extraFree: {
    free = [testCore (useArtifacts ["free-blob"])] ++ extraFree;
    full = [(useArtifacts ["redist-fw" "cached-fw" "operator-fw"])];
  };
  fixturesWith = extraFree:
    config.boards.internal.mkFixtures {
      board = "test-board";
      entry = testEntry extraFree;
      manifests = [valid];
    };
  inherit (config.boards.internal) evaluates;
  fixtureAssertions = nixos: map (a: a.message) (lib.filter (a: !a.assertion) nixos.config.assertions);
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    fetch = testFetch pkgs;
    unfreePkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.unfreePackages [valid]);
    };
    cachePkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = boardsLib.namePredicate (boardsLib.cacheablePackages [valid]);
    };
    artifact = p: id:
      boardsLib.mkArtifact {
        pkgs = p;
        manifest = valid;
        inherit id fetch;
      };
    flashFirmware = boardsLib.mkFlashTool {
      inherit pkgs;
      board = "test-board";
      firmware = artifact unfreePkgs "redist-fw";
      target = "a temporary file named by $FLASH_TARGET";
      recovery = "Delete the temporary file.";
      write = ''cp "$1" "$FLASH_TARGET"'';
    };
  in {
    checks =
      {
        lib-manifests = assert expect (boardsLib.manifestErrors valid == []) "valid manifest has errors: ${toString (boardsLib.manifestErrors valid)}";
        assert expect (sortedEq (boardsLib.manifestErrors invalid) data.expectedErrors)
        "invalid manifest errors differ: ${builtins.toJSON (boardsLib.manifestErrors invalid)}";
        assert expect (sortedEq (boardsLib.unfreePackages [valid]) (map name ["redist-fw" "operator-fw" "runtime-bundle" "operator-tool"])) "unfree package list follows nixpkgs license semantics";
        assert expect (boardsLib.cacheablePackages [valid] == [(name "cached-fw")]) "cacheable package list";
        assert expect (sortedEq (boardsLib.nonCacheableHashes [valid])
          (map data.sri [data.contents."redist.bin" data.contents."operator.bin" data.contents."nocache.bin" data.contents."mystery.bin"])) "non-cacheable hashes";
        assert expect (!(failsToEval (artifact pkgs "nocache-fw").drvPath)) "nixpkgs counts unfreeRedistributableFirmware as free";
        assert expect (sortedEq (boardsLib.nonPrivateHashes [valid])
          (map data.sri [data.contents."redist.bin" data.contents."cached.bin" data.contents."nocache.bin" data.contents."mystery.bin"])) "non-private hashes";
        assert expect (failsToEval (artifact unfreePkgs "mystery-fw").drvPath) "blocked artifact must not package";
        assert expect (failsToEval (artifact pkgs "redist-fw").drvPath) "R1 artifact must need an unfree allowance";
        assert expect (!(failsToEval (artifact pkgs "free-blob").drvPath)) "R0 artifact must not need an unfree allowance";
        assert expect (failsToEval (artifact cachePkgs "redist-fw").drvPath) "gate 1: R1 without cache clearance must fail under the cache predicate";
        assert expect (!(failsToEval (artifact cachePkgs "cached-fw").drvPath)) "gate 1: cache-cleared R1 must evaluate under the cache predicate"; let
          r2 = boardsLib.mkArtifact {
            pkgs = unfreePkgs;
            manifest = valid;
            id = "operator-fw";
          };
        in
          assert expect (!r2.allowSubstitutes && r2.preferLocalBuild) "R2 artifact must not be substituted";
          assert expect (!(failsToEval r2.drvPath)) "R2 artifact must evaluate to a requireFile build";
            pkgs.runCommand "nixos-boards-lib-manifests" {} "touch $out";

        lib-built = let
          bundle = p:
            boardsLib.mkBuilt {
              manifest = valid;
              id = "runtime-bundle";
              package = p.runCommand (name "runtime-bundle") {} "touch $out";
            };
          entry = (bundle pkgs).manifestEntry;
          misnamed = boardsLib.mkBuilt {
            manifest = valid;
            id = "runtime-bundle";
            package = pkgs.runCommand "something-else" {} "touch $out";
          };
          importTool = boardsLib.mkImportTool {
            inherit pkgs;
            name = "test-board-import-artifacts";
            manifests = [valid];
          };
        in
          assert expect (entry.class == "R1" && entry.built && entry.from == ["redist-fw"]) "built packages carry their manifest entry";
          assert expect ((bundle pkgs).meta.license.shortName == "LicenseRef-test-board-firmware") "built packages take the manifest license";
          assert expect (failsToEval (bundle pkgs).drvPath) "a non-free built package needs an unfree allowance";
          assert expect (!(failsToEval (bundle unfreePkgs).drvPath)) "the generated unfree list admits built packages";
          assert expect (failsToEval misnamed) "built packages must be named <manifest>-<id>";
          assert expect (!(builtins.elem (name "runtime-bundle") (boardsLib.cacheablePackages [valid]))) "built packages without cache clearance are not cacheable";
            pkgs.runCommand "nixos-boards-lib-built" {} ''
              grep -q -F 'test-board.operator-fw|operator.bin|' ${lib.getExe importTool}
              ! grep -q -F 'test-board.redist-fw' ${lib.getExe importTool}
              touch "$out"
            '';

        lib-artifacts = let
          r0 = artifact pkgs "free-blob";
          r1 = artifact unfreePkgs "redist-fw";
        in
          pkgs.runCommand "nixos-boards-lib-artifacts" {} ''
            test -f ${r0}/lib/firmware/test/free.bin
            test -f ${r1}/lib/firmware/test/redist.bin
            test -f ${r1}/share/licenses/${r1.pname}/0-LICENSE.redist
            touch $out
          '';

        lib-artifact-integrity = let
          tampered = boardsLib.mkArtifact {
            pkgs = unfreePkgs;
            manifest = valid;
            id = "redist-fw";
            fetch = {name, ...}: pkgs.writeText name "redistributable firmwarX\n";
          };
        in
          pkgs.testers.testBuildFailure tampered;

        lib-claims = let
          conflict = boardAssertions [(claim "addon-hat-a" ["header:8" "header:10"]) (claim "addon-hat-b" ["header:10"])];
          clean = boardAssertions [(claim "addon-hat-a" ["header:8"]) (claim "addon-hat-b" ["header:10"])];
          foreign = boardAssertions [{hardware.boards.artifacts = [pkgs.hello];}];
        in
          assert expect (conflict == ["hardware.boards.claims: resource header:10 is claimed by addon-hat-a, addon-hat-b"])
          "conflicting claims: ${builtins.toJSON conflict}";
          assert expect (clean == []) "distinct claims must not conflict: ${builtins.toJSON clean}";
          assert expect (foreign == ["hardware.boards.artifacts: ${pkgs.hello.name} was not built from a release manifest"])
          "non-manifest artifact: ${builtins.toJSON foreign}";
            pkgs.runCommand "nixos-boards-lib-claims" {} "touch $out";

        lib-fixtures = let
          ok = fixturesWith [];
          leak = fixturesWith [(useArtifacts ["redist-fw"])];
          nixpkgsFirmware = fixturesWith [({pkgs, ...}: {hardware.firmware = [pkgs.linux-firmware];})];
          firmwareFree = fixturesWith [(useArtifacts ["nocache-fw"])];
          buildOnly =
            (fixturesWith [
              ({pkgs, ...}: {
                hardware.boards.artifacts = [
                  (boardsLib.mkBuilt {
                    manifest = valid;
                    id = "operator-tool";
                    package = pkgs.runCommand (name "operator-tool") {} "touch $out";
                  })
                ];
              })
            ]).free;
          pushSet = fixture:
            boardsLib.mkPublicPushSet {
              inherit pkgs fixture;
              name = "test-board-public-push-set";
              publish = ["toplevel"];
              manifests = [];
            };
          ownAllowance = fixturesWith [{nixpkgs.config.allowUnfreePredicate = _: true;}];
          otherManifest = config.boards.internal.mkFixtures {
            board = "test-board";
            entry = testEntry [];
            manifests = [];
          };
          wrongProvider = fixturesWith [({pkgs, ...}: {boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor (boardsLib.withProvider "mainline" pkgs.linux));})];
          hasMessage = nixos: fragment: lib.any (lib.hasInfix fragment) (fixtureAssertions nixos);
        in
          assert expect (!(failsToEval (evaluates ok.free))) "free fixture must evaluate: ${builtins.toJSON (fixtureAssertions ok.free)}";
          assert expect (!(failsToEval (evaluates ok.full))) "full fixture must evaluate: ${builtins.toJSON (fixtureAssertions ok.full)}";
          assert expect ok.free.config.hardware.boards.publication.private "a fixture with only R0 artifacts may enter the private cache";
          assert expect (sortedEq ok.full.config.hardware.boards.publication.blocking ["test-board.redist-fw" "test-board.cached-fw"]) "artifacts without redistribution.private block the private cache: ${builtins.toJSON ok.full.config.hardware.boards.publication.blocking}";
          assert expect (!ok.full.config.hardware.boards.publication.private) "a blocked system is not private-publishable";
          assert expect ok.full.config.hardware.boards.publication.build "file and private grants imply internal build copies";
          assert expect (buildOnly.config.hardware.boards.publication.buildBlocking == ["test-board.operator-tool"]) "an R2 package without build permission blocks internal build copies: ${builtins.toJSON buildOnly.config.hardware.boards.publication.buildBlocking}";
          assert expect (!buildOnly.config.hardware.boards.publication.build) "a build-blocked system reports build = false";
          assert expect (lib.any (lib.hasInfix "uses the test-1.0 provider, not mainline") ok.free.config.warnings) "non-mainline provider warning";
          assert expect (failsToEval (evaluates leak.free)) "an R1 artifact in the free profile must fail";
          assert expect (!(failsToEval (evaluates nixpkgsFirmware.free))) "the free profile follows nixpkgs: linux-firmware evaluates";
          assert expect (!(failsToEval (evaluates firmwareFree.free))) "the free profile follows nixpkgs: unfreeRedistributableFirmware artifacts evaluate";
          assert expect (!(failsToEval (pushSet ok.free).drvPath)) "gate 1: a free fixture without manifest artifacts is publishable";
          assert expect (failsToEval (pushSet firmwareFree.free).drvPath) "gate 1: an artifact not cleared for cache must block the push set";
          assert expect (hasMessage ownAllowance.full "features must not set nixpkgs.config") "a feature's own unfree allowance must fail";
          assert expect (hasMessage otherManifest.full "comes from a manifest not listed") "artifacts from unlisted manifests must fail";
          assert expect (hasMessage wrongProvider.free "the kernel's provider (mainline) is not test-1.0") "provider mismatch must fail";
            pkgs.runCommand "nixos-boards-lib-fixtures" {} "touch $out";

        lib-docs = let
          pages = boardsLib.docPages {
            page = "Test-Board";
            manifests = [valid];
            haveHardware = false;
            functions = {
              console = {
                status = "verified";
                reason = null;
                evidence = "https://example.invalid/log";
                features = ["test-board-core"];
              };
              wifi = {
                status = "implemented-unverified";
                reason = null;
                evidence = null;
                features = ["test-board-wireless"];
              };
              audio = {
                status = "pending";
                reason = null;
                evidence = null;
                features = ["test-board-audio"];
              };
              dsp = {
                status = "blocked";
                reason = "licensing";
                evidence = null;
                features = ["test-board-dsp"];
              };
            };
          };
          has = file: fragment: expect (lib.hasInfix fragment pages.${file}) "${file} lacks: ${fragment}\n${pages.${file}}";
        in
          assert has "Test-Board-Hardware-Matrix.md" "| console | verified | free | test-board-core | [evidence](https://example.invalid/log) |";
          assert has "Test-Board-Hardware-Matrix.md" "| wifi | implemented-unverified | full |";
          assert has "Test-Board-Hardware-Matrix.md" "| dsp | blocked: licensing | blocked: licensing |";
          assert has "Test-Board-Hardware-Matrix.md" "do not have this board";
          assert has "Test-Board-Firmware.md" "| `mystery-fw` | blocked: licensing | R1 |";
          assert has "Test-Board-Firmware.md" "| `cached-fw` | adopted | R1 | unfreeRedistributableFirmware | runtime-firmware | firmware | file, image, cache |";
          assert has "Test-Board-Free-vs-NonFree.md" "## boot-firmware";
          assert has "Test-Board-Firmware.md" "| `runtime-bundle` | R1 | LicenseRef-test-board-firmware | `redist-fw`, synthetic runtime sources (test license) | userspace | userspace | file, image |";
          assert has "Test-Board-Free-vs-NonFree.md" "| test-board-runtime | `test-board.runtime-bundle` | R1 | full |";
          assert expect (lib.hasInfix "uses no artifacts from release manifests"
            (boardsLib.docPages {
              page = "Empty-Board";
              manifests = [];
              haveHardware = false;
              functions = {};
            })."Empty-Board-Firmware.md") "boards without manifests say where firmware comes from";
          assert has "Test-Board-Free-vs-NonFree.md" "| test-board-firmware | `test-board.operator-fw` | R2 | full |";
          assert has "Test-Board-Free-vs-NonFree.md" "| test-board-dsp | `test-board.mystery-fw` | R1 | blocked: licensing |";
          assert has "Test-Board-Hardware-Matrix.md" "| audio | pending | free |";
          assert expect (!(lib.hasInfix "free-blob" pages."Test-Board-Free-vs-NonFree.md")) "R0 artifacts are not gaps";
          assert expect (!(lib.hasInfix "nocache-fw" pages."Test-Board-Free-vs-NonFree.md")) "artifacts nixpkgs counts as free are not gaps";
            pkgs.runCommand "nixos-boards-lib-docs" {} "touch $out";

        lib-cache-scan = let
          scan = boardsLib.mkCacheScan {
            inherit pkgs;
            hashes = boardsLib.nonCacheableHashes [valid];
          };
          # A non-cacheable blob copied under an unrelated name.
          leak = pkgs.runCommand "innocent-data" {} ''
            mkdir -p $out/share
            cp ${pkgs.writeText "x" data.contents."redist.bin"} $out/share/innocent.dat
          '';
          clean = [(artifact unfreePkgs "cached-fw") (artifact pkgs "free-blob")];
        in
          pkgs.runCommand "nixos-boards-lib-cache-scan" {
            nativeBuildInputs = [scan];
            leakClosure = pkgs.closureInfo {rootPaths = [leak];};
            cleanClosure = pkgs.closureInfo {rootPaths = clean;};
          } ''
            # expect STATUS MESSAGE ARGS...: the scan exits with STATUS and says MESSAGE.
            expect() {
              want=$1 message=$2
              shift 2
              status=0
              nixos-boards-cache-scan "$@" 2>err || status=$?
              [ "$status" -eq "$want" ] || { echo "status $status, wanted $want: $*" >&2; cat err >&2; exit 1; }
              grep -q -- "$message" err || { echo "wanted \"$message\" for: $*" >&2; cat err >&2; exit 1; }
            }

            # Without nix-store, nothing can be validated.
            expect 2 "nix-store is needed" --closure-file "$cleanClosure/store-paths"
            expect 2 "nix-store is needed" "$(head -n 1 "$cleanClosure/store-paths")"

            # A stub store: registered paths and the requisites a query returns.
            mkdir bin
            export PATH=$PWD/bin:$PATH MOCK=$PWD
            cat "$leakClosure/store-paths" "$cleanClosure/store-paths" > registered
            cat > bin/nix-store <<'SH'
            #!${pkgs.runtimeShell}
            case "$1" in
              --check-validity)
                shift
                for p in "$@"; do grep -qxF "$p" "$MOCK/registered" || { echo "path '$p' is not valid" >&2; exit 1; }; done ;;
              --query)
                case "$(cat "$MOCK/query")" in
                  fail) exit 1 ;;
                  empty) ;;
                  *) cat "$(cat "$MOCK/query")" ;;
                esac ;;
              *) exit 2 ;;
            esac
            SH
            chmod +x bin/nix-store
            answer() { echo "$1" > query; }

            answer "$leakClosure/store-paths"
            expect 1 innocent.dat --closure-file "$leakClosure/store-paths"
            answer "$cleanClosure/store-paths"
            nixos-boards-cache-scan --closure-file "$cleanClosure/store-paths"

            # Malformed, missing, unregistered or incomplete lists fail closed.
            : > empty
            expect 2 "missing or empty" --closure-file empty
            expect 2 "missing or empty" --closure-file absent
            echo relative/path > relative
            expect 2 "not a top-level store path" --closure-file relative
            missing=${builtins.storeDir}/00000000000000000000000000000000-missing
            echo "$missing" > invalid
            expect 2 "does not exist" --closure-file invalid
            { cat "$leakClosure/store-paths"; echo "$missing"; } > mixed
            expect 2 "does not exist" --closure-file mixed
            top=$(head -n 1 "$leakClosure/store-paths")
            for bad in "$top/share" "$top/share/.." "$top/." "${builtins.storeDir}/.$(basename "$top")"; do
              { cat "$cleanClosure/store-paths"; echo "$bad"; } > nested
              expect 2 "not a top-level store path" --closure-file nested
            done
            # Exists in the store, but is not registered.
            unregistered=$(dirname "$(dirname ${pkgs.runtimeShell})")
            echo "$unregistered" > unknown
            expect 2 "not valid in the Nix store" --closure-file unknown
            head -n 1 "$cleanClosure/store-paths" > partial
            expect 2 "omits" --closure-file partial
            answer fail
            expect 2 "could not query" --closure-file "$cleanClosure/store-paths"
            # A query that succeeds with nothing, or with less than the roots.
            answer empty
            expect 2 "returned no closure" --closure-file "$cleanClosure/store-paths"
            head -n 1 "$cleanClosure/store-paths" > short
            answer short
            expect 2 "does not report" --closure-file "$cleanClosure/store-paths"

            # Querying store paths directly: arguments are checked first.
            for bad in "$top/share" "$top/share/.." relative "$missing"; do
              expect 2 "Refusing" "$bad"
            done
            expect 2 "not valid in the Nix store" "$unregistered"
            answer fail
            expect 2 "could not query" "$top"
            answer empty
            expect 2 "does not include" "$top"
            answer "$leakClosure/store-paths"
            expect 1 innocent.dat "$top"
            answer "$cleanClosure/store-paths"
            expect 2 "does not include" "$top"
            { echo "$top"; echo "$unregistered"; } > unknown-closure
            answer unknown-closure
            expect 2 "not valid in the Nix store" "$top"
            touch $out
          '';

        lib-flash-tool =
          pkgs.runCommand "nixos-boards-lib-flash-tool" {
            nativeBuildInputs = [flashFirmware];
          } ''
            export FLASH_TARGET=$TMPDIR/flashed
            status=0
            test-board-flash-firmware </dev/null >/dev/null 2>err || status=$?
            test "$status" -eq 2
            grep -q 'refusing to run without an interactive terminal' err
            test ! -e "$FLASH_TARGET"
            touch $out
          '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        # util-linux `script` supplies the interactive terminal the tool requires.
        lib-flash-tool-interactive =
          pkgs.runCommand "nixos-boards-lib-flash-tool-interactive" {
            nativeBuildInputs = [flashFirmware pkgs.util-linux];
          } ''
            export FLASH_TARGET=$TMPDIR/flashed
            echo wrong-board | script -qec test-board-flash-firmware /dev/null >wrong || true
            test ! -e "$FLASH_TARGET"
            echo test-board | script -qec test-board-flash-firmware /dev/null >right
            cmp "$FLASH_TARGET" ${artifact unfreePkgs "redist-fw"}/lib/firmware/test/redist.bin
            grep -q 'Recovery if this fails' right
            touch $out
          '';
      };
  };
}
