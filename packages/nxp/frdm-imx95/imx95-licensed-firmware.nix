# Operator-supplied NXP boot firmware (R2), from the release manifest.
# Each output holds the single file at its file name.
{
  callPackage,
  frdmArtifact,
}: {
  ele = frdmArtifact "ele-firmware";
  lpddr4xDmem = frdmArtifact "lpddr4x-dmem";
  lpddr4xDmemQuickBoot = frdmArtifact "lpddr4x-dmem-qb";
  lpddr4xImem = frdmArtifact "lpddr4x-imem";
  lpddr4xImemQuickBoot = frdmArtifact "lpddr4x-imem-qb";
  m7PowerModeDemo =
    callPackage ./nxp-imx95-m7-power-mode-demo.nix {};
}
