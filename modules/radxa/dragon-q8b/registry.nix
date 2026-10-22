{
  config,
  inputs,
  lib,
  ...
}: {
  boards.manifests.dragon-q8b-firmware = import ../../../packages/radxa/dragon-q8b/firmware.manifest.nix {inherit lib;};
  boards.manifests.dragon-q8b-mainline = import ../../../packages/radxa/dragon-q8b/mainline.manifest.nix {
    kernelVersion = inputs.nixpkgs.legacyPackages.aarch64-linux.linux.version;
    nixpkgsRevision = inputs.nixpkgs.rev;
  };
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
        status = "verified";
        reason = "recorded 2026-10-13 full-profile headless consumer; not current public-fixture hardware acceptance";
        evidence = "Dragon-Q8B-Boot-and-Recovery#headless-hardware-acceptance";
        features = ["dragon-q8b-core"];
      };
      ethernet = {
        status = "verified";
        reason = "recorded 2026-10-13 full-profile headless consumer, one PCIe link/warm boots; not current public-fixture hardware acceptance";
        evidence = "Dragon-Q8B-Boot-and-Recovery#headless-hardware-acceptance";
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
        status = "verified";
        reason = "recorded 2026-10-13 full-profile headless consumer, 512-byte sectors; not current public-fixture or physical 4Kn acceptance";
        evidence = "Dragon-Q8B-Boot-and-Recovery#headless-hardware-acceptance";
        features = ["dragon-q8b-core"];
      };
      ufs = {
        status = "verified";
        reason = "recorded 2026-10-21 full-profile headless consumer, 4096-byte sectors, YMTC 128 GB module";
        evidence = "Dragon-Q8B-Boot-and-Recovery#ufs-boot";
        features = ["dragon-q8b-core"];
      };
    };
  };
}
