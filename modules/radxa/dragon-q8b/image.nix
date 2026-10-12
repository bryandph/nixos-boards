{
  config,
  inputs,
  ...
}: {
  flake.modules.nixos.dragon-q8b-image = {
    config,
    lib,
    pkgs,
    ...
  }: let
    rootfs =
      (pkgs.callPackage (inputs.nixpkgs + "/nixos/lib/make-ext4-fs.nix") {
        storePaths = [config.system.build.toplevel];
        volumeLabel = "NIXOS_Q8B";
        uuid = "81ad85de-22d0-4e73-8ebb-0512b0000004";
        populateImageCommands = ''
          mkdir -p files/boot files/etc files/nix/var/nix/profiles
          ln -s ${config.system.build.toplevel}/init files/init
          touch files/etc/NIXOS
          ln -s ${config.system.build.toplevel} files/nix/var/nix/profiles/system
        '';
      }).overrideAttrs (old: {
        # e2fsprogs otherwise picks a random directory hash seed.
        buildCommand =
          lib.replaceStrings ["fakeroot mkfs.ext4"]
          ["fakeroot mkfs.ext4 -E hash_seed=81ad85de-22d0-4e73-8ebb-0512b0000004"]
          old.buildCommand;
      });
    image = sectorSize:
      pkgs.callPackage ../../../packages/radxa/dragon-q8b/image.nix {
        inherit config rootfs sectorSize;
      };
  in {
    fileSystems."/" = lib.mkDefault {
      device = "/dev/disk/by-label/NIXOS_Q8B";
      fsType = "ext4";
    };
    fileSystems."/boot" = lib.mkDefault {
      device = "/dev/disk/by-label/BOOT_Q8B";
      fsType = "vfat";
    };
    boot.growPartition = true;
    system.build = {
      image512 = image 512;
      image4096 = image 4096;
      image = config.system.build.image512;
    };
    systemd.services.register-nix-paths = {
      description = "Register fixture Nix store paths on first boot";
      wantedBy = ["sysinit.target"];
      before = ["sysinit.target" "shutdown.target" "nix-daemon.socket" "nix-daemon.service"];
      after = ["local-fs.target"];
      conflicts = ["shutdown.target"];
      unitConfig = {
        DefaultDependencies = false;
        ConditionPathExists = "/nix-path-registration";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.getExe' config.nix.package.out "nix-store"} --load-db < /nix-path-registration
        ${lib.getExe' config.nix.package.out "nix-env"} -p /nix/var/nix/profiles/system --set /run/current-system
        rm -f /nix-path-registration
      '';
    };
    # Immutable GPT layout v1: 1 MiB alignment, 512 MiB ESP, ext4 root.
    system.nixos.tags = ["dragon-q8b-layout-v1"];
  };
  flake.nixosModules.dragon-q8b-image = config.flake.modules.nixos.dragon-q8b-image;
}
