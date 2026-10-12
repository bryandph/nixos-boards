# Synthetic release manifests for the library tests. Contents are
# generated here, so the tests need no network and no real vendor files.
{lib}: let
  contents = {
    "free.bin" = "free firmware\n";
    "redist.bin" = "redistributable firmware\n";
    "cached.bin" = "cache-cleared firmware\n";
    "operator.bin" = "operator-supplied firmware\n";
    "mystery.bin" = "firmware with an unknown license\n";
    "LICENSE.redist" = "Redistribution of the unmodified file is permitted.\n";
  };
  sri = text:
    builtins.convertHash {
      hash = builtins.hashString "sha256" text;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };
  file = name: {
    url = "https://example.invalid/${name}";
    size = builtins.stringLength contents.${name};
    sha256 = sri contents.${name};
  };
  notice = {
    url = "https://example.invalid/LICENSE.redist";
    sha256 = sri contents."LICENSE.redist";
  };
  testLicense = {
    shortName = "LicenseRef-test-board-firmware";
    fullName = "Test board firmware license";
    free = false;
    redistributable = true;
  };
  operatorLicense = {
    shortName = "LicenseRef-test-board-eula";
    fullName = "Test board end-user license";
    free = false;
    redistributable = false;
  };
  evidence = {
    url = "https://example.invalid/license";
    retrieved = "2026-10-11";
    location = "section 2";
  };
in {
  inherit contents sri;

  valid = {
    provider = "test-1.0";
    version = "1.0";
    source = "synthetic test release";
    artifacts = {
      free-blob =
        file "free.bin"
        // {
          class = "R0";
          path = "lib/firmware/test/free.bin";
          license = lib.licenses.mit;
          layer = "runtime-firmware";
          load = "firmware";
          features = ["test-board-core"];
        };
      redist-fw =
        file "redist.bin"
        // {
          class = "R1";
          path = "lib/firmware/test/redist.bin";
          license = testLicense;
          inherit evidence;
          notices = [notice];
          redistribution = {
            file = true;
            image = true;
          };
          layer = "runtime-firmware";
          load = "firmware";
          features = ["test-board-wireless"];
        };
      cached-fw =
        file "cached.bin"
        // {
          class = "R1";
          path = "lib/firmware/test/cached.bin";
          license = lib.licenses.unfreeRedistributableFirmware;
          inherit evidence;
          notices = [notice];
          redistribution = {
            file = true;
            image = true;
            cache = true;
          };
          layer = "runtime-firmware";
          load = "firmware";
          features = ["test-board-bluetooth"];
        };
      operator-fw =
        (file "operator.bin")
        // {
          class = "R2";
          url = null;
          path = "lib/firmware/test/operator.bin";
          license = operatorLicense;
          inherit evidence;
          instructions = "Download operator.bin from the vendor portal after accepting its license.";
          redistribution.private = true;
          layer = "boot-firmware";
          load = "board-storage";
          features = ["test-board-firmware"];
        };
      mystery-fw = {
        status = "blocked";
        blockedReason = "licensing";
        class = "R1";
        path = "lib/firmware/test/mystery.bin";
        inherit (file "mystery.bin") sha256;
        layer = "runtime-firmware";
        load = "remoteproc";
        features = ["test-board-dsp"];
      };
    };
  };

  # Each artifact violates one rule; the test expects every message.
  invalid = {
    provider = "test-1.0";
    version = "1.0";
    source = "synthetic invalid release";
    artifacts = {
      r0-unfree =
        file "free.bin"
        // {
          class = "R0";
          path = "a";
          license = testLicense;
          layer = "userspace";
          load = "userspace";
        };
      r1-no-evidence =
        file "redist.bin"
        // {
          class = "R1";
          path = "b";
          license = testLicense;
          notices = [notice];
          redistribution.file = true;
          layer = "runtime-firmware";
          load = "firmware";
        };
      r1-cache-only =
        file "cached.bin"
        // {
          class = "R1";
          path = "c";
          license = testLicense;
          inherit evidence;
          notices = [notice];
          redistribution.cache = true;
          layer = "runtime-firmware";
          load = "firmware";
        };
      r2-public =
        file "operator.bin"
        // {
          class = "R2";
          path = "d";
          license = operatorLicense;
          inherit evidence;
          redistribution.image = true;
          layer = "boot-firmware";
          load = "board-storage";
        };
      blocked-no-reason = {
        status = "blocked";
        class = "R1";
        path = "e";
        layer = "runtime-firmware";
        load = "firmware";
      };
    };
  };

  expectedErrors = [
    "invalid.r0-unfree: R0 requires a free license"
    "invalid.r1-no-evidence: non-free artifacts require license evidence"
    "invalid.r1-cache-only: R1 requires redistribution.file"
    "invalid.r1-cache-only: redistribution.cache requires redistribution.file"
    "invalid.r2-public: R2 requires import instructions"
    "invalid.r2-public: R2 artifacts cannot be publicly redistributable"
    "invalid.blocked-no-reason: blocked artifacts must name a blockedReason"
  ];
}
