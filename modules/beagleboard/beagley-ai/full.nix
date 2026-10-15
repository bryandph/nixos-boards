# Every non-free BeagleY-AI feature: boot firmware, codec, GPU, Wi-Fi/BLE,
# C7x vision firmware, accelerator runtime and the camera pipeline. The
# vision and accelerator features need imported R2 artifacts.
{config, ...}: {
  flake.modules.nixos.beagley-ai-full = {
    imports = with config.flake.modules.nixos; [
      beagley-ai-boot-bundle
      beagley-ai-multimedia
      beagley-ai-gpu
      beagley-ai-wireless
      beagley-ai-vision
      beagley-ai-accelerator-runtime
      beagley-ai-camera
    ];
  };

  flake.nixosModules.beagley-ai-full = config.flake.modules.nixos.beagley-ai-full;
}
