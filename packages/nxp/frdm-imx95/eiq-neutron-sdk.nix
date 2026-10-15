{
  autoPatchelfHook,
  lib,
  python311Packages,
  stdenv,
  zlib,
  frdmArtifact,
  frdmBuilt,
}: let
  wheel = let
    artifact = frdmArtifact "eiq-neutron-sdk-wheel";
  in "${artifact}/${artifact.manifestEntry.path}";
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  converter = release.neutron.converter;
in
  frdmBuilt "eiq-neutron-sdk" (python311Packages.buildPythonPackage {
    pname = "frdm-imx95-eiq-neutron-sdk";
    inherit (converter) version;
    format = "wheel";
    src = wheel;

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [
      stdenv.cc.cc.lib
      zlib
    ];

    preUnpack = ''
      test "$(sha256sum "$src" | cut -d' ' -f1)" = ${converter.sha256}
    '';
    postInstall = ''
      ln -s neutron_converter "$out/bin/neutron-converter"
    '';

    doCheck = false;
    pythonImportsCheck = ["eiq_neutron_sdk"];

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      releaseMapping = release;
      wheelSha256 = converter.sha256;
    };

    meta = {
      description = "Operator-supplied NXP eIQ Neutron SDK converter";
      homepage = converter.index;
      hydraPlatforms = [];
      mainProgram = "neutron_converter";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
