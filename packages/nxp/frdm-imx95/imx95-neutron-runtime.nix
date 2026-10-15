{
  lib,
  runCommand,
  frdmArtifact,
  frdmBuilt,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  runtime = release.neutron.runtime;
  ids = {
    "NeutronFirmware.elf" = "neutron-firmware";
    "libNeutronDriver.so" = "neutron-driver";
    "NeutronDriver.h" = "neutron-driver-header";
    "NeutronErrors.h" = "neutron-errors-header";
  };
  mkMember = member: installedPath: let
    fileName = builtins.baseNameOf member.path;
  in
    member
    // {
      inherit fileName installedPath;
      src = let
        artifact = frdmArtifact ids.${fileName};
      in "${artifact}/${artifact.manifestEntry.path}";
    };
  members =
    [
      (mkMember runtime.members.firmware "lib/firmware/NeutronFirmware.elf")
      (mkMember runtime.members.driver "lib/libNeutronDriver.so")
    ]
    ++ map (
      header:
        mkMember header "include/neutron/${builtins.baseNameOf header.path}"
    )
    runtime.members.headers;
  verification =
    lib.concatMapStringsSep "\n" (
      member: ''
        source_path=${member.src}
        test -f "$source_path"
        test "$(stat -c %s "$source_path")" = ${toString member.size}
        test "$(sha256sum "$source_path" | cut -d' ' -f1)" = ${member.sha256}
        install -Dm0444 "$source_path" "$out/${member.installedPath}"
      ''
    )
    members;
in
  frdmBuilt "neutron-runtime" (runCommand "frdm-imx95-neutron-runtime-${release.neutron.versionLabels.sbom}" {
      allowSubstitutes = false;
      preferLocalBuild = true;

      passthru = {
        inherit members;
        releaseMapping = release;
        runtimeRevision = runtime.rev;
      };

      meta = {
        description = "Operator-imported NXP Neutron firmware, userspace driver, and headers";
        homepage = runtime.repository;
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      mkdir -p "$out"
      ${verification}
    '')
