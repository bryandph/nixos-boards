#!/usr/bin/env bash
# Every layout-v1 image carries the same fixed GPT identifiers so builds stay
# reproducible. Give a disk that still has them its own disk and partition GUIDs.
# The running kernel is not told: this boot keeps its devices, the next boot
# (and systemd-boot's LoaderDevicePartUUID) sees the new identifiers.
set -euo pipefail
disk=$1
fixed=$2
current=$(sfdisk --disk-id "$disk")
if [ "${current,,}" != "${fixed,,}" ]; then
  exit 0
fi
# Partitions first, disk GUID last: an interrupted run is repeated next boot.
for n in 1 2; do
  sfdisk --no-reread --no-tell-kernel --part-uuid "$disk" "$n" "$(cat /proc/sys/kernel/random/uuid)"
done
sfdisk --no-reread --no-tell-kernel --disk-id "$disk" "$(cat /proc/sys/kernel/random/uuid)"
