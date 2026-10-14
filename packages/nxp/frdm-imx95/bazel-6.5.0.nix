{
  enableNixHacks ? false,
  stdenv,
}: let
  # Same reviewed tree identity, fetched as an evaluator input rather than
  # importing a derivation output (which would require IFD).
  nixpkgs = builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "e7eabdc701d7dbb810fd91a97ec358caa4c1fc50";
    narHash = "sha256-di5L6e5Iiv+oegS07j9h23FdqEpXn0ZQqMlDOEMw1EY=";
  };
in
  (import nixpkgs.outPath {
    system = stdenv.buildPlatform.system;
  }).bazel.override {inherit enableNixHacks;}
