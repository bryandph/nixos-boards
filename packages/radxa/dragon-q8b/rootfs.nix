{
  pkgs,
  lib,
  nixpkgs,
  toplevel,
}: let
  uuid = "81ad85de-22d0-4e73-8ebb-0512b0000004";
  mkfs = ''faketime -f "1970-01-01 00:00:01" fakeroot mkfs.ext4'';
  copy = "cp -a --reflink=auto";
  # libext2fs chooses s_flags' directory-hash signedness using native char.
  # ARM and x86 defaults differ; select signed semantics BEFORE population,
  # rather than editing the superblock after directory hashes are constructed.
  e2fsprogs = pkgs.e2fsprogs.overrideAttrs (old: {
    env =
      (old.env or {})
      // {
        NIX_CFLAGS_COMPILE = "${old.env.NIX_CFLAGS_COMPILE or ""} -fsigned-char";
      };
  });
in
  (pkgs.callPackage (nixpkgs + "/nixos/lib/make-ext4-fs.nix") {
    storePaths = [toplevel];
    volumeLabel = "NIXOS_Q8B";
    inherit uuid e2fsprogs;
    populateImageCommands = ''
      mkdir -p files/boot files/etc files/nix/var/nix/profiles
      ln -s ${toplevel}/init files/init
      touch files/etc/NIXOS
      ln -s ${toplevel} files/nix/var/nix/profiles/system
    '';
  }).overrideAttrs (old: {
    requiredSystemFeatures = lib.unique ((old.requiredSystemFeatures or []) ++ ["big-parallel"]);
    # Fixed fs UUID alone is insufficient: mkdir/cp staging times and the
    # directory hash seed otherwise vary. Fail closed if the upstream hook moves.
    buildCommand = assert builtins.length (lib.splitString mkfs old.buildCommand) == 2;
    assert builtins.length (lib.splitString copy old.buildCommand) == 3;
      lib.replaceStrings [copy mkfs] [
        # NARs do not encode hardlinks. Never inherit builder-store optimisation.
        "cp -a --no-preserve=links --reflink=auto"
        ("test -z \"$(find ./rootImage -type f -links +1 -print -quit)\"\n"
          + "find ./rootImage -exec touch -h -d @1 {} +\n"
          + "${mkfs} -b 4096 -E hash_seed=${uuid},lazy_itable_init=0,lazy_journal_init=0")
      ]
      old.buildCommand;
  })
