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
  testCore = {
    imports = [config.flake.modules.nixos.hardware-boards];
    nixpkgs.hostPlatform = "aarch64-linux";
    hardware.boards = {
      identity = {
        board = "test-board";
        vendor = "test";
        soc = "test-soc";
        bootChain = "board";
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
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    fetch = {
      name,
      url,
      ...
    }:
      pkgs.writeText name data.contents.${baseNameOf url};
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
        lib-manifests = assert expect (boardsLib.manifestErrors valid == []) "valid manifest has errors: ${toString (boardsLib.manifestErrors valid)}";
        assert expect (sortedEq (boardsLib.manifestErrors invalid) data.expectedErrors)
        "invalid manifest errors differ: ${builtins.toJSON (boardsLib.manifestErrors invalid)}";
        assert expect (sortedEq (boardsLib.unfreePackages [valid]) (map name ["redist-fw" "cached-fw" "operator-fw"])) "unfree package list";
        assert expect (boardsLib.cacheablePackages [valid] == [(name "cached-fw")]) "cacheable package list";
        assert expect (sortedEq (boardsLib.nonCacheableHashes [valid])
          (map data.sri [data.contents."redist.bin" data.contents."operator.bin" data.contents."mystery.bin"])) "non-cacheable hashes";
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
