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
    # Runs only after a successful generation install; preserve bootstrap on failure.
    boot.loader.systemd-boot.extraInstallCommands = lib.mkAfter ''
      ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/cleanup-bootstrap.sh} ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint} /nix-path-registration
    '';
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
        ${pkgs.runtimeShell} ${../../../packages/radxa/dragon-q8b/initialize-profile.sh} ${lib.getExe' config.nix.package.out "nix-env"} /nix/var/nix/profiles/system /run/current-system
      '';
    };
    # Keep EFI installation out of pre-sysinit registration: ordinary service
    # ordering is available, and a failed install cannot delay store registration.
    systemd.services.install-initial-bootloader = {
      description = "Replace the Dragon Q8B bootstrap with managed boot generations";
      wantedBy = ["multi-user.target"];
      requires = ["register-nix-paths.service"];
      after = ["register-nix-paths.service" "local-fs.target"];
      unitConfig.ConditionPathExists = "/nix-path-registration";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Failure leaves the marker/bootstrap intact for a retry on next boot.
        NIXOS_INSTALL_BOOTLOADER=1 /run/current-system/bin/switch-to-configuration boot
        rm -f /nix-path-registration
      '';
    };
    # Immutable GPT layout v1: 1 MiB alignment, 512 MiB ESP, ext4 root.
    system.nixos.tags = ["dragon-q8b-layout-v1"];
  };
  flake.nixosModules.dragon-q8b-image = config.flake.modules.nixos.dragon-q8b-image;
}
