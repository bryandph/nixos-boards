#!/usr/bin/env bash
# Registration retries must not reset an existing managed profile to the booted
# generation (which may be an older menu selection).
set -euo pipefail
nix_env=$1
profile=$2
current=$3
target=$(readlink "$profile" || true)
case "${target##*/}" in
system-[0-9]*-link) ;; # already a managed profile, preserve its selection
*) "$nix_env" -p "$profile" --set "$current" ;;
esac
