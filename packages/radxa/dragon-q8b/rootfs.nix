{
  pkgs,
  lib,
  nixpkgs,
  toplevel,
}: let
  uuid = "81ad85de-22d0-4e73-8ebb-0512b0000004";
  mkfs = ''faketime -f "1970-01-01 00:00:01" fakeroot mkfs.ext4'';
in
  (pkgs.callPackage (nixpkgs + "/nixos/lib/make-ext4-fs.nix") {
    storePaths = [toplevel];
    volumeLabel = "NIXOS_Q8B";
    inherit uuid;
    populateImageCommands = ''
      mkdir -p files/boot files/etc files/nix/var/nix/profiles
      ln -s ${toplevel}/init files/init
      touch files/etc/NIXOS
      ln -s ${toplevel} files/nix/var/nix/profiles/system
    '';
  }).overrideAttrs (old: {
    # Fixed fs UUID alone is insufficient: mkdir/cp staging times and the
    # directory hash seed otherwise vary. Fail closed if the upstream hook moves.
    buildCommand = assert builtins.length (lib.splitString mkfs old.buildCommand) == 2;
      lib.replaceStrings [mkfs] [
        ("find ./rootImage -exec touch -h -d @1 {} +\n"
          + "${mkfs} -b 4096 -E hash_seed=${uuid},lazy_itable_init=0,lazy_journal_init=0")
      ]
      old.buildCommand;
  })
