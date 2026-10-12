{lib, ...}: {
  perSystem = {pkgs, ...}: {
    # Specifications and active changes must stay valid.
    checks.openspec =
      pkgs.runCommand "nixos-boards-openspec" {
        nativeBuildInputs = [pkgs.openspec];
        src = lib.fileset.toSource {
          root = ../.;
          fileset = ../openspec;
        };
        # Without CI set, openspec waits on an interactive prompt in the sandbox.
        CI = "1";
        DO_NOT_TRACK = "1";
        OPENSPEC_TELEMETRY = "0";
      } ''
        export HOME=$TMPDIR
        cp -r "$src" repo
        chmod -R u+w repo
        cd repo
        openspec validate --all --strict --no-color
        touch $out
      '';
  };
}
