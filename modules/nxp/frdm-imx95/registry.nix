{
  config,
  lib,
  ...
}: let
  inherit (config.flake.modules) nixos;
  data = import ../../../packages/nxp/frdm-imx95/manifest.nix {};
  status = s: features: {
    status = s;
    inherit features;
  };
  scripts = ../../../packages/nxp/frdm-imx95/scripts;
in {
  boards.manifests.frdm-imx95 = data.manifest;

  boards.registry.frdm-imx95 = {
    page = "FRDM-i.MX95";
    # The mainline kernel and open GPU/JPEG userspace need no NXP files.
    free = [nixos.frdm-imx95-core nixos.frdm-imx95-image nixos.frdm-imx95-multimedia nixos.frdm-imx95-nvme];
    full = [nixos.frdm-imx95-full];
    manifests = ["frdm-imx95"];
    haveHardware = true;
    functions = {
      boot = status "implemented-unverified" ["frdm-imx95-boot-container"];
      serial-console = status "implemented-unverified" ["frdm-imx95-core"];
      sd-card = status "implemented-unverified" ["frdm-imx95-image"];
      gpu = status "implemented-unverified" ["frdm-imx95-multimedia"];
      jpeg = status "implemented-unverified" ["frdm-imx95-multimedia"];
      nvme = status "implemented-unverified" ["frdm-imx95-nvme"];
      audio = status "implemented-unverified" ["frdm-imx95-audio"];
      m7-remoteproc = status "implemented-unverified" ["frdm-imx95-m7-remoteproc"];
      neutron-npu = status "implemented-unverified" ["frdm-imx95-neutron-npu"];
      wave6-vpu = status "implemented-unverified" ["frdm-imx95-wave6-vpu"];
    };
  };

  # Operator-run imports of NXP files (R2). Each verifies the release-pinned
  # distribution and runs NXP's extractor only after --accept-license.
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    importApp = name: script: runtimeInputs: description: {
      type = "app";
      meta = {inherit description;};
      program = lib.getExe (pkgs.writeShellApplication {
        inherit name runtimeInputs;
        text = builtins.readFile (scripts + "/${script}");
      });
    };
    common = [pkgs.coreutils pkgs.nix pkgs.gawk pkgs.gnutar pkgs.gzip pkgs.xz];
  in {
    checks.frdm-imx95-import-acceptance-guards = pkgs.runCommand "frdm-imx95-import-acceptance-guards" {} ''
      mkdir bin
      for command in nix-store curl unzip; do
        printf '#!${pkgs.runtimeShell}\nprintf touched >> "$CALLS"\nexit 99\n' > "bin/$command"
        chmod +x "bin/$command"
      done
      export CALLS=$PWD/calls
      export PATH="$PWD/bin:$PATH"
      for script in ${scripts}/import-nxp-{firmware,wave6-firmware,m7-power-mode-demo,boot-container}; do
        for mode in absent invalid; do
          status=0
          if [ "$mode" = absent ]; then
            ${pkgs.runtimeShell} "$script" > output 2>&1 || status=$?
          else
            ${pkgs.runtimeShell} "$script" --not-accepted > output 2>&1 || status=$?
          fi
          test "$status" -eq 2
          grep -F -- '--accept-license' output
          test ! -e calls
        done
      done
      touch "$out"
    '';
    apps =
      lib.optionalAttrs (system == "x86_64-linux") {
        frdm-imx95-convert-neutron-model = {
          type = "app";
          meta.description = "Convert and import the Neutron smoke model with NXP's eIQ Neutron SDK";
          program = lib.getExe ((import ./_scope.nix {inherit config;}) pkgs).convertNeutronModel;
        };
      }
      // {
        frdm-imx95-import-nxp-firmware = importApp "frdm-imx95-import-nxp-firmware" "import-nxp-firmware" common "Import the FRDM-i.MX95 ELE and LPDDR4X firmware after accepting NXP's license";
        frdm-imx95-import-nxp-wave6-firmware = importApp "frdm-imx95-import-nxp-wave6-firmware" "import-nxp-wave6-firmware" common "Import the firmware-imx distribution for the Wave6 VPU after accepting NXP's license";
        frdm-imx95-import-nxp-m7-power-mode-demo = importApp "frdm-imx95-import-nxp-m7-power-mode-demo" "import-nxp-m7-power-mode-demo" (common ++ [pkgs.unzip]) "Import NXP's M7 power-mode demo (compatibility only) after accepting NXP's license";
        frdm-imx95-import-nxp-boot-container = importApp "frdm-imx95-import-nxp-boot-container" "import-nxp-boot-container" (common ++ [pkgs.unzip]) "Import NXP's complete FRDM-i.MX95 boot container (compatibility and recovery)";
        frdm-imx95-import-artifacts = {
          type = "app";
          meta.description = "List the FRDM-i.MX95's operator-supplied (R2) files and import the downloadable ones after accepting their terms";
          program = lib.getExe (config.boards.lib.mkImportTool {
            inherit pkgs;
            name = "frdm-imx95-import-artifacts";
            manifests = [config.boards.manifests.frdm-imx95];
          });
        };
        frdm-imx95-import-neutron-runtime = {
          type = "app";
          meta.description = "Import the NXP Neutron runtime members after accepting NXP's license";
          program = lib.getExe ((import ./_scope.nix {inherit config;}) pkgs).importNeutronRuntime;
        };
      };
  };
}
