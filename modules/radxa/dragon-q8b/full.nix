{config, ...}: {
  # Full is optional; evaluating it is safe, building requires operator import.
  # Missing CDSP/topology/QUP/UEFI grants are not bypassed by this composition.
  flake.modules.nixos.dragon-q8b-full.imports = with config.flake.modules.nixos; [dragon-q8b-adsp dragon-q8b-gpu];
  flake.nixosModules.dragon-q8b-full = config.flake.modules.nixos.dragon-q8b-full;
}
