#!/usr/bin/env bash
# Called only after NixOS has successfully installed managed generation entries.
set -euo pipefail
esp=$1
marker=$2
rm -f "$esp/loader/entries/dragon-q8b-bootstrap.conf"
rm -f "$esp/dragon-q8b-bootstrap/linux" "$esp/dragon-q8b-bootstrap/initrd" \
  "$esp/dragon-q8b-bootstrap/dragon-q8b.dtb"
# Preserve any unknown files rather than recursively deleting a directory.
if [ -d "$esp/dragon-q8b-bootstrap" ]; then
  rmdir "$esp/dragon-q8b-bootstrap" 2>/dev/null || true
fi
# Also covers a successful manual rebuild after a failed initial install.
rm -f "$marker"
