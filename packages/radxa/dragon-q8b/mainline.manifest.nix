{
  provider = "mainline";
  version = "6.18.54";
  source = "nixpkgs f45c6f04c2f013f004bf94e284e95d72898d9393 default mainline kernel; Q8B native DTS absent";
  artifacts.native-dtb = {
    status = "blocked";
    blockedReason = "compatible native Q8B DTS or reviewed backport required";
    class = "R0";
    path = "dtbs/qcom/sc8280xp-radxa-dragon-q8b.dtb";
    layer = "kernel";
    load = "boot-image";
    features = ["dragon-q8b-provider-mainline"];
  };
}
