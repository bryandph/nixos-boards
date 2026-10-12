{
  config,
  lib,
  ...
}: {
  boards.manifests.dragon-q8b-firmware = import ../../../packages/radxa/dragon-q8b/firmware.manifest.nix {inherit lib;};
  boards.manifests.dragon-q8b-mainline = import ../../../packages/radxa/dragon-q8b/mainline.manifest.nix;
  boards.registry.dragon-q8b = {
    page = "Dragon-Q8B";
    free = with config.flake.modules.nixos; [dragon-q8b-core dragon-q8b-image];
    full = [config.flake.modules.nixos.dragon-q8b-full];
    manifests = ["dragon-q8b-firmware" "dragon-q8b-mainline"];
    publish = ["toplevel" "image512" "image4096"];
    haveHardware = true;
    functions = {
      mainline = {
        status = "blocked";
        reason = "compatible native Q8B DTS or reviewed backport required";
        features = ["dragon-q8b-provider-mainline"];
      };
      serial = {
        status = "implemented-unverified";
        features = ["dragon-q8b-core"];
      };
      ethernet = {
        status = "implemented-unverified";
        features = ["dragon-q8b-core"];
      };
      gpu = {
        status = "implemented-unverified";
        features = ["dragon-q8b-gpu"];
      };
      adsp = {
        status = "implemented-unverified";
        features = ["dragon-q8b-adsp"];
      };
      audio = {
        status = "blocked";
        reason = "licensing (topology)";
        features = ["dragon-q8b-audio"];
      };
      compute-dsp = {
        status = "blocked";
        reason = "licensing";
        features = ["dragon-q8b-compute-dsp"];
      };
      qup = {
        status = "blocked";
        reason = "licensing";
        features = ["dragon-q8b-qup"];
      };
      video = {
        status = "blocked";
        reason = "licensing";
        features = ["dragon-q8b-video"];
      };
      sd = {
        status = "implemented-unverified";
        features = ["dragon-q8b-core"];
      };
      nvme = {
        status = "implemented-unverified";
        features = ["dragon-q8b-core"];
      };
      ufs = {
        status = "implemented-unverified";
        features = ["dragon-q8b-core"];
      };
    };
  };
}
