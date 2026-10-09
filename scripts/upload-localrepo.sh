#!/usr/bin/env bash
# Publish the prebuilt packages in localrepo/ as assets of the "localrepo"
# release so CI can download them. Re-run after rebuilding any package.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${1:-guruswarupa/Lindows7}
shopt -s nullglob
pkgs=(localrepo/*.pkg.tar.zst)
pkgs=("${pkgs[@]/*-debug-*/}")
files=()
for f in "${pkgs[@]}"; do [ -n "$f" ] && files+=("$f"); done
gh release view localrepo --repo "$repo" >/dev/null 2>&1 || \
  gh release create localrepo --repo "$repo" --prerelease \
    --title "localrepo packages" --notes "Prebuilt AUR packages used by the ISO build. Not a user-facing release."
gh release upload localrepo --repo "$repo" --clobber "${files[@]}"
