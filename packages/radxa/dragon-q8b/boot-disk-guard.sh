#!/usr/bin/env bash
# Stage 1: the root is found on the disk holding the ESP systemd-boot loaded
# from. Refuse to guess if that ESP's partition GUID is on several disks, as
# happens when two freshly written images are attached before first boot.
set -euo pipefail
var=/sys/firmware/efi/efivars/LoaderDevicePartUUID-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f
udevadm settle --timeout=30 || true
if [ ! -r "$var" ]; then
  echo "dragon-q8b: LoaderDevicePartUUID is not readable; cannot identify the boot disk" >&2
  exit 1
fi
esp=$(tail -c +5 "$var" | tr -d '\0')
esp=${esp,,}
matches=()
for dev in /sys/class/block/*; do
  [ -e "$dev/partition" ] || continue
  id=$(udevadm info --query=property --property=ID_PART_ENTRY_UUID --value --path="$dev" || true)
  if [ "${id,,}" = "$esp" ]; then
    matches+=("/dev/${dev##*/}")
  fi
done
if [ "${#matches[@]}" -ne 1 ]; then
  echo "dragon-q8b: boot ESP $esp found on ${#matches[@]} partitions (${matches[*]}); detach all but the boot disk" >&2
  exit 1
fi
# Disks probed before EFI variables were readable lack the gpt-auto markers.
udevadm trigger --action=change --subsystem-match=block --settle
