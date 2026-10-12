{
  kernelVersion,
  nixpkgsRevision,
}: {
  provider = "mainline";
  version = kernelVersion;
  source = "locked nixpkgs ${nixpkgsRevision} default mainline kernel; Q8B compatibility not established and no provider exported";
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
