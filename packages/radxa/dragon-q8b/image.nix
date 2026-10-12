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
  system = config.system.build.toplevel;
  dtb = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  sector = toString sectorSize;
in
  pkgs.runCommand "dragon-q8b-uefi-${sector}-v1.img" {
    nativeBuildInputs = [pkgs.util-linux pkgs.dosfstools pkgs.mtools pkgs.libfaketime];
    passthru = {
      inherit sectorSize;
      layoutVersion = 1;
    };
  } ''
    export TZ=UTC
    mkdir -p esp/EFI/BOOT esp/loader/entries esp/nixos
    cp ${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi esp/EFI/BOOT/BOOTAA64.EFI
    cp -L ${system}/kernel esp/nixos/linux
    cp -L ${system}/initrd esp/nixos/initrd
    cp ${dtb} esp/nixos/dragon-q8b.dtb
    cat > esp/loader/loader.conf <<'EOF'
    default nixos
    timeout 3
    EOF
    cat > esp/loader/entries/nixos.conf <<'EOF'
    title NixOS Dragon Q8B
    linux /nixos/linux
    initrd /nixos/initrd
    devicetree /nixos/dragon-q8b.dtb
    options init=${system}/init root=LABEL=NIXOS_Q8B ${lib.concatStringsSep " " config.boot.kernelParams}
    EOF
    # Fixed creation times, volume ID, disk GUID and partition GUIDs.
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
    label-id: 81ad85de-22d0-4e73-8ebb-0512b0000001
    unit: sectors
    sector-size: ${sector}
    start=$align, size=$esp_sectors, type=U, name="EFI System", uuid=81ad85de-22d0-4e73-8ebb-0512b0000002
    start=$root_start, size=$root_sectors, type=L, name="NixOS", uuid=81ad85de-22d0-4e73-8ebb-0512b0000003
    EOF
    dd if=esp.img of="$out" bs=${sector} seek="$align" conv=notrunc status=none
    dd if=${rootfs} of="$out" bs=${sector} seek="$root_start" conv=notrunc status=none
  ''
