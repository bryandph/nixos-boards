{
  autoPatchelfHook,
  cmake,
  lib,
  ninja,
  runtime,
  source,
  stdenv,
  tensorflowLite,
  tensorflowLiteSource ? tensorflowLite.src,
  frdmBuilt,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  delegate = release.neutron.delegate;
in
  frdmBuilt "tflite-neutron-delegate" (stdenv.mkDerivation {
    pname = "frdm-imx95-tflite-neutron-delegate";
    version = delegate.version;
    src = source;

    nativeBuildInputs = [
      autoPatchelfHook
      cmake
      ninja
    ];
    buildInputs = [
      runtime
      tensorflowLite
    ];

    postPatch = ''
      cp ${./Findtensorflow-nix.cmake} cmake/modules/Findtensorflow.cmake
    '';
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DNEUTRON_INTEGRATION=ON"
      "-DNEUTRON_DRIVER_PATH=${runtime}"
      "-DNEUTRON_DRIVER_LIB=${runtime}/lib/libNeutronDriver.so"
      "-DTFLITE_SOURCE_DIR=${tensorflowLiteSource}/tensorflow/lite"
      "-DTFLITE_LIB_LOC=${tensorflowLite}/lib/libtensorflowlite.so"
      "-DTFLITE_INCLUDE_DIR=${tensorflowLite}/include"
    ];
    installPhase = ''
      runHook preInstall
      install -Dm0555 libneutron_delegate.so "$out/lib/libneutron_delegate.so"
      install -Dm0444 "$src/neutron_delegate.h" "$out/include/neutron_delegate.h"
      runHook postInstall
    '';

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      releaseMapping = release;
      sourceRevision = delegate.rev;
      runtimeRevision = release.neutron.runtime.rev;
    };

    meta = {
      description = "TensorFlow Lite Neutron delegate linked to the licensed NXP runtime";
      homepage = delegate.repository;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
    };
  })
