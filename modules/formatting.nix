{
  perSystem = {
    config,
    lib,
    ...
  }: {
    treefmt.config = {
      projectRootFile = "flake.nix";
      programs.actionlint.enable = true;
      programs.alejandra.enable = true;
      programs.deadnix.enable = true;
      programs.shellcheck.enable = true;
      programs.shfmt.enable = true;
    };
    formatter = config.treefmt.build.wrapper;
    apps.fmt = {
      type = "app";
      program = lib.getExe config.treefmt.build.wrapper;
      meta.description = "Format board support sources";
    };
  };
}
