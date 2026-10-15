# Open GPU (Panthor, Mesa) and JPEG (mxc-jpeg) support. Free.
{config, ...}: let
  frdm = import ./_scope.nix {inherit config;};
in {
  flake.modules.nixos.frdm-imx95-multimedia = {
    config,
    pkgs,
    ...
  }: let
    scope = frdm pkgs;
    inherit (scope) release gpuSmoke jpegSmoke;
    providerKind = config.boot.kernelPackages.kernel.providerKind or "upstream";
  in {
    hardware.graphics.enable = true;
    users.groups.video = {};
    services.udev.extraRules = ''
      SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", ATTR{name}=="mxc-jpeg*", GROUP="video", MODE="0660"
    '';
    environment.systemPackages = [
      gpuSmoke
      jpegSmoke
      pkgs.v4l-utils
      pkgs.vulkan-tools
    ];
    system.build = {
      inherit gpuSmoke jpegSmoke;
    };
    assertions = [
      {
        assertion =
          providerKind
          == "upstream"
          || providerKind == "nxp-full-combined";
        message = ''
          Open multimedia probes require either the upstream provider or the
          reviewed combined NXP provider.
        '';
      }
      {
        assertion = release.multimedia.mainline.gpu.userspace == "mesa";
        message = "Mainline multimedia must use the open Mesa userspace.";
      }
    ];
  };

  flake.nixosModules.frdm-imx95-multimedia = config.flake.modules.nixos.frdm-imx95-multimedia;
}
