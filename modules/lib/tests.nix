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
        lib-manifests = let
          mislabeledFirmware = boardsLib.evalManifest "test-board" (data.valid
            // {
              artifacts =
                data.valid.artifacts
                // {
                  free-blob = data.valid.artifacts.free-blob // {license = lib.licenses.unfreeRedistributableFirmware;};
                };
            });
          rejectedFirmware = boardsLib.mkArtifact {
            pkgs = unfreePkgs;
            manifest = mislabeledFirmware;
            id = "free-blob";
            inherit fetch;
          };
        in
          assert expect (boardsLib.manifestErrors mislabeledFirmware != []) "non-free redistributable firmware is not R0/FOSS";
          assert expect (failsToEval rejectedFirmware.drvPath) "R0 vendor firmware misclassification must not package";
          assert expect (boardsLib.manifestErrors valid == []) "valid manifest has errors: ${toString (boardsLib.manifestErrors valid)}";
          assert expect (sortedEq (boardsLib.manifestErrors invalid) data.expectedErrors)
          "invalid manifest errors differ: ${builtins.toJSON (boardsLib.manifestErrors invalid)}";
          assert expect (sortedEq (boardsLib.unfreePackages [valid]) (map name ["redist-fw" "operator-fw" "runtime-bundle" "operator-tool"])) "unfree package list follows nixpkgs license semantics";
          assert expect (!(failsToEval (artifact pkgs "nocache-fw").drvPath)) "nixpkgs counts unfreeRedistributableFirmware as free";
          assert expect (failsToEval (artifact unfreePkgs "mystery-fw").drvPath) "blocked artifact must not package";
          assert expect (failsToEval (artifact pkgs "redist-fw").drvPath) "R1 artifact must need an unfree allowance";
          assert expect (!(failsToEval (artifact pkgs "free-blob").drvPath)) "R0 artifact must not need an unfree allowance"; let
            r2 = boardsLib.mkArtifact {
              pkgs = unfreePkgs;
              manifest = valid;
              id = "operator-fw";
            };
          in
            assert expect (!r2.allowSubstitutes && r2.preferLocalBuild) "R2 artifact must not be substituted";
            assert expect (!(failsToEval r2.drvPath)) "R2 artifact must evaluate to a requireFile build";
              pkgs.runCommand "nixos-boards-lib-manifests" {} "touch $out";

        lib-internal-use = let
          interpretation = {
            accepted = true;
            target = "Synthetic TI-device internal build";
            rationale = "Pinned published build flow; bounded intended-use evidence, not a grant.";
            uncertainty = "No independently established helper redistribution grant.";
            evidence = {
              url = "https://example.invalid/pinned-source";
              retrieved = "2026-10-14";
              location = "Synthetic source/use evidence, not license terms.";
            };
          };
          raw =
            data.valid
            // {
              artifacts =
                data.valid.artifacts
                // {
                  operator-fw =
                    data.valid.artifacts.operator-fw
                    // {
                      redistribution = {};
                      internalUse = interpretation;
                    };
                };
              built =
                data.valid.built
                // {
                  operator-tool = data.valid.built.operator-tool // {internalUse = interpretation;};
                };
            };
          m = boardsLib.evalManifest "test-board" raw;
          changedArtifact = attrs:
            boardsLib.evalManifest "test-board" (raw
              // {
                artifacts = raw.artifacts // {operator-fw = raw.artifacts.operator-fw // attrs;};
              });
          errors = x: boardsLib.manifestErrors x;
          a = boardsLib.mkArtifact {
            pkgs = unfreePkgs;
            manifest = m;
            id = "operator-fw";
            inherit fetch;
          };
          b = boardsLib.mkBuilt {
            manifest = m;
            id = "operator-tool";
            package = unfreePkgs.runCommand (name "operator-tool") {} ''mkdir -p "$out"'';
          };
          privateOutput = boardsLib.evalManifest "test-board" (raw
            // {
              built =
                raw.built
                // {
                  operator-tool =
                    raw.built.operator-tool
                    // {
                      internalUse = null;
                      redistribution.private = true;
                    };
                };
            });
          licensedBuildOutput = boardsLib.evalManifest "test-board" (raw
            // {
              built =
                raw.built
                // {
                  operator-tool =
                    raw.built.operator-tool
                    // {
                      internalUse = null;
                      redistribution.build = true;
                    };
                };
            });
          customInstall = hook:
            boardsLib.mkBuilt {
              manifest = m;
              id = "operator-tool";
              package = unfreePkgs.stdenvNoCC.mkDerivation {
                pname = name "operator-tool";
                version = "1.0";
                outputs = ["out" "dev"];
                dontUnpack = true;
                installPhase = ''
                  mkdir -p "$out" "$dev"
                  ${lib.optionalString hook "runHook postInstall"}
                '';
              };
            };
          noInputAcceptance = changedArtifact {internalUse = null;};
        in
          assert expect (errors m == []) "accepted internal interpretation must validate";
          assert expect (a.manifestEntry.internalUse.accepted && b.manifestEntry.internalUse.accepted) "accepted interpretation metadata is retained";
          assert expect (!a.manifestEntry.redistribution.build && !b.manifestEntry.redistribution.build) "interpretation must not masquerade as licensed build permission";
          assert expect (!a.meta.license.redistributable && !b.meta.license.redistributable) "interpretation must not set license redistributable";
          assert expect (lib.all (form: !a.manifestEntry.redistribution.${form} && !b.manifestEntry.redistribution.${form}) ["file" "image" "cache" "private"]) "all affected redistribution forms stay denied";
          assert expect (errors (changedArtifact {internalUse = interpretation // {accepted = false;};}) != []) "missing explicit acceptance fails closed";
          assert expect (errors (changedArtifact {internalUse = interpretation // {target = "";};}) != []) "missing target fails closed";
          assert expect (errors (changedArtifact {license = raw.artifacts.operator-fw.license // {redistributable = true;};}) != []) "interpretation cannot promote license redistributability";
          assert expect (errors (changedArtifact {internalUse = interpretation // {rationale = "";};}) != []) "missing rationale fails closed";
          assert expect (errors (changedArtifact {internalUse = interpretation // {uncertainty = "";};}) != []) "missing uncertainty fails closed";
          assert expect (errors (changedArtifact {internalUse = interpretation // {evidence = interpretation.evidence // {url = "";};};}) != []) "missing source evidence fails closed";
          assert expect (lib.all (form: errors (changedArtifact {redistribution.${form} = true;}) != []) ["file" "image" "cache" "private" "build"]) "interpretation may not coexist with redistribution grants";
          assert expect (errors licensedBuildOutput != []) "derived licensed build grant cannot be laundered from interpreted inputs";
          assert expect (failsToEval (customInstall false).drvPath) "custom installPhase without notice hook fails closed";
          assert expect (!(failsToEval (customInstall true).drvPath)) "custom installPhase with notice hook validates";
          assert expect (lib.all (field: errors (changedArtifact {internalUse = interpretation // {${field} = " \t\n";};}) != []) ["target" "rationale" "uncertainty"]) "whitespace-only interpretation text fails closed";
          assert expect (lib.all (field: errors (changedArtifact {internalUse = interpretation // {evidence = interpretation.evidence // {${field} = " \t\n";};};}) != []) ["url" "location"]) "whitespace-only evidence fails closed";
          assert expect (errors privateOutput != []) "derived private permission cannot exceed helper inputs";
          assert expect (errors noInputAcceptance != []) "derived internal build cannot exceed helper inputs";
            pkgs.runCommand "nixos-boards-lib-internal-use" {} ''
              grep -F 'NOT an express vendor grant' ${a}/share/licenses/test-board-operator-fw/internal-use-interpretation.txt
              grep -F 'NOT an express vendor grant' ${b}/share/licenses/test-board-operator-tool/internal-use-interpretation.txt
              grep -F 'NOT an express vendor grant' ${customInstall true}/share/licenses/test-board-operator-tool/internal-use-interpretation.txt
              grep -F 'NOT an express vendor grant' ${(customInstall true).dev}/share/licenses/test-board-operator-tool/internal-use-interpretation.txt
              touch "$out"
            '';

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
          assert expect (lib.any (lib.hasInfix "uses the test-1.0 provider, not mainline") ok.free.config.warnings) "non-mainline provider warning";
          assert expect (failsToEval (evaluates leak.free)) "an R1 artifact in the free profile must fail";
          assert expect (!(failsToEval (evaluates nixpkgsFirmware.free))) "the free profile follows nixpkgs: linux-firmware evaluates";
          assert expect (!(failsToEval (evaluates firmwareFree.free))) "the free profile follows nixpkgs: unfreeRedistributableFirmware artifacts evaluate";
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

        lib-public-targets = let
          fixture.config.system.build.toplevel = pkgs.writeText "configured-fixture" "fixture";
          extra = artifact unfreePkgs "redist-fw";
          targets = boardsLib.mkPublicPushSet {
            inherit pkgs fixture;
            name = "configured-public-targets";
            publish = ["toplevel"];
            artifacts = [extra];
          };
        in
          assert expect (!valid.artifacts.redist-fw.redistribution.cache) "test target has no cache flag";
          assert expect (toString targets.entries.${extra.name} == extra.outPath) "explicit standalone target is not filtered by license flags";
          assert expect (builtins.length (builtins.attrNames targets.entries) == 2) "configured fixture and standalone target only";
            pkgs.writeText "nixos-boards-public-targets" "Explicit configured targets; no publication policing.\n";

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
