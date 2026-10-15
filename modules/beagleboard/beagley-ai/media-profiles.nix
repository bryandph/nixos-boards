{config, ...}: let
  inherit (config.flake.modules.nixos) hardware-boards;
  claims = owner: resources:
    map (resource: {
      inherit resource owner;
    })
    resources;
in {
  flake.modules.nixos = {
    beagley-ai-oldi-lcd185 = {
      imports = [hardware-boards];
      hardware.boards.claims = claims "oldi-lcd185" ["connector:oldi" "gpio:mcu0:11" "gpio:main0:14" "pwm:ecap0" "i2c:main1:0x57" "i2c:main1:0x5d" "display:dss0:vp1"];
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-oldi-lcd185";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/beagleboard/beagley-ai/multimedia-oldi-lcd185.dtso;
        }
      ];
    };
    beagley-ai-csi0-imx219 = {
      imports = [hardware-boards];
      hardware.boards.claims = claims "csi0-imx219" ["connector:csi0" "gpio:mcu0:15" "i2c:main2:0x10"];
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-csi0-imx219";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/beagleboard/beagley-ai/multimedia-csi0-imx219.dtso;
        }
      ];
    };
    beagley-ai-csi1-imx219 = {
      imports = [hardware-boards];
      hardware.boards.claims = claims "csi1-imx219" ["connector:csi1-dsi0" "gpio:main0:1" "gpio:main0:2" "gpio:main1:24" "i2c:main0:0x10"];
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-csi1-imx219";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/beagleboard/beagley-ai/multimedia-csi1-imx219.dtso;
        }
      ];
    };
    beagley-ai-dsi-rpi-7inch = {
      imports = [hardware-boards];
      hardware.boards.claims = claims "dsi-rpi-7inch" ["connector:csi1-dsi0" "gpio:main0:1" "gpio:main0:2" "i2c:main0:0x45" "display:dss1:vp2"];
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-dsi-rpi-7inch";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/beagleboard/beagley-ai/multimedia-dsi-rpi-7inch.dtso;
        }
      ];
    };
  };
}
