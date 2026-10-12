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
    rootfs = pkgs.callPackage ../../../packages/radxa/dragon-q8b/rootfs.nix {
      nixpkgs = inputs.nixpkgs;
      toplevel = config.system.build.toplevel;
    };
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
      rootfsImage = rootfs;
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
