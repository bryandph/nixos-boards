{config, ...}: let
  inherit (config.flake.modules.nixos) hardware-boards;
in {
  perSystem = {pkgs, ...}: {
    checks = {
      beagley-ai-usb-gadget-cleanup = let
        script = ../../../packages/beagleboard/beagley-ai/usb-gadget.sh;
      in
        pkgs.runCommand "beagley-ai-usb-gadget-cleanup" {} ''
          mkdir bin
          # configfs removes a group's attribute files with the directory.
          cat > bin/rmdir <<'SH'
          #!${pkgs.runtimeShell}
          if [ -e "$1/UDC" ]; then printf '%s\n' "$(cat "$1/UDC")" >> "$LOG"; fi
          chmod -R u+w "$1" && rm -rf "$1"
          SH
          chmod +x bin/rmdir
          export PATH="$PWD/bin:$PATH"

          tree() {
            root=$PWD/$1
            mkdir -p "$root/strings/0x409" "$root/configs/c.1/strings/0x409" "$root/functions/acm.usb0" "$root/functions/ecm.usb0"
            ln -s "$root/functions/acm.usb0" "$root/configs/c.1/acm.usb0"
            printf '%s\n' "$2" > "$root/UDC"
            sed "s|^root=.*|root=$root|" ${script} > "$1.sh"
          }
          run() { LOG=$PWD/$1.log bash "$1.sh" stop; }

          # Unbound, after a partial setup: no unbind, whole tree removed.
          tree unbound ""
          chmod 444 unbound/UDC
          run unbound
          test ! -e unbound
          [ "$(cat unbound.log)" = "" ]

          # Bound: unbound first, then removed.
          tree bound 31000000.usb
          run bound
          test ! -e bound
          [ "$(cat bound.log)" = "" ]

          # An unreadable UDC is an error, and nothing is removed.
          tree unreadable 31000000.usb
          chmod 000 unreadable/UDC
          if run unreadable; then echo "unreadable UDC was ignored"; exit 1; fi
          test -d unreadable/functions/acm.usb0

          # A retry after a failed partial setup cleans up the same way.
          tree retry ""
          chmod 444 retry/UDC
          run retry && test ! -e retry
          touch $out
        '';
    };
  };

  flake.modules.nixos.beagley-ai-usb-gadget = {pkgs, ...}: let
    gadget = pkgs.writeShellApplication {
      name = "beagley-usb-gadget";
      runtimeInputs = [pkgs.coreutils];
      text = builtins.readFile ../../../packages/beagleboard/beagley-ai/usb-gadget.sh;
    };
  in {
    imports = [hardware-boards];
    hardware.boards.claims = [
      {
        resource = "usb:usb0";
        owner = "acm-ecm-gadget";
      }
    ];
    hardware.deviceTree.overlays = [
      {
        name = "beagley-ai-usb-device";
        filter = "k3-am67a-beagley-ai";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / { compatible = "beagle,am67a-beagley-ai"; };
          &usb0 { dr_mode = "peripheral"; };
        '';
      }
    ];
    boot.kernelModules = ["libcomposite" "usb_f_acm" "usb_f_ecm"];
    systemd.services.beagley-usb-gadget = {
      description = "BeagleY-AI USB-C serial and Ethernet gadget";
      wantedBy = ["multi-user.target"];
      requires = ["sys-kernel-config.mount"];
      after = ["sys-kernel-config.mount" "systemd-modules-load.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 45;
        ExecStart = "${gadget}/bin/beagley-usb-gadget start";
        ExecStop = "${gadget}/bin/beagley-usb-gadget stop";
      };
    };
  };
}
