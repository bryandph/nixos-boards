# Layout v1: GPT, a 512 MiB FAT32 ESP, then an ext4 root filesystem.
# The sector size changes both GPT addressing and the FAT BPB, not just a filename.
{
  pkgs,
  lib,
  config,
  rootfs,
  sectorSize,
}:
assert builtins.elem sectorSize [512 4096]; let
  ids = import ./layout.nix;
  system = config.system.build.toplevel;
  dtb = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  sector = toString sectorSize;
in
  pkgs.runCommand "dragon-q8b-uefi-${sector}-v1.img" {
    nativeBuildInputs = [pkgs.util-linux pkgs.dosfstools pkgs.mtools pkgs.libfaketime];
    requiredSystemFeatures = ["big-parallel"];
    # Several GiB of media construction: use the scheduler's heavy lane.
    passthru = {
      inherit sectorSize;
      layoutVersion = 1;
    };
  } ''
    export TZ=UTC
    mkdir -p esp/EFI/BOOT esp/loader/entries esp/dragon-q8b-bootstrap
    cp ${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi esp/EFI/BOOT/BOOTAA64.EFI
    cp -L ${system}/kernel esp/dragon-q8b-bootstrap/linux
    cp -L ${system}/initrd esp/dragon-q8b-bootstrap/initrd
    cp ${dtb} esp/dragon-q8b-bootstrap/dragon-q8b.dtb
    cat > esp/loader/loader.conf <<'EOF'
    default dragon-q8b-bootstrap
    timeout 3
    EOF
    cat > esp/loader/entries/dragon-q8b-bootstrap.conf <<'EOF'
    title NixOS Dragon Q8B (bootstrap)
    linux /dragon-q8b-bootstrap/linux
    initrd /dragon-q8b-bootstrap/initrd
    devicetree /dragon-q8b-bootstrap/dragon-q8b.dtb
    options init=${system}/init ${lib.concatStringsSep " " config.boot.kernelParams}
    EOF
    # Fixed creation times, volume ID, disk GUID and partition GUIDs; the GUIDs
    # are replaced on first boot so written copies stay distinguishable.
    find esp -exec touch -h -t 198001010000 {} +
    truncate -s 512M esp.img
    faketime '1980-01-01 00:00:00' mkfs.vfat --invariant -F 32 -S ${sector} -n BOOT_Q8B -i 5128B001 esp.img
    faketime '1980-01-01 00:00:00' mcopy -i esp.img -s esp/* ::/

    align=$((1048576 / ${sector}))
    esp_sectors=$((536870912 / ${sector}))
    root_start=$((align + esp_sectors))
    root_bytes=$(stat -c %s ${rootfs})
    root_sectors=$(((root_bytes + ${sector} - 1) / ${sector}))
    # Leave one MiB for the backup GPT and alignment.
    total_bytes=$(((root_start + root_sectors + align) * ${sector}))
    truncate -s "$total_bytes" "$out"
    sfdisk --sector-size ${sector} "$out" <<EOF
    label: gpt
    label-id: ${ids.diskId}
    unit: sectors
    sector-size: ${sector}
    start=$align, size=$esp_sectors, type=U, name="EFI System", uuid=${ids.espId}
    start=$root_start, size=$root_sectors, type=${ids.rootType}, name="NixOS", uuid=${ids.rootId}
    EOF
    dd if=esp.img of="$out" bs=${sector} seek="$align" conv=notrunc status=none
    dd if=${rootfs} of="$out" bs=${sector} seek="$root_start" conv=notrunc status=none
  ''
