#!/bin/bash
# Build InputPlumber v0.84.0 with one of this tweak's touchpad patches, in a throwaway container.
# Nothing on the system is changed: the result is written to ./out/ next to this script.
#
#   build/build-patched.sh glide       # lift-off filter "glide" variant (runs on the reference device)
#   build/build-patched.sh tapfilter   # lift-off filter "tapfilter" variant (best measured tap precision)
#
# Needs: podman (preinstalled on SteamOS), network access, ~2 GB disk, 3-10 minutes.
# Then install with:  LG_IP_BINARY=<path printed below> ./legiongo.sh install precision-touchpad
set -euo pipefail
VARIANT="${1:-}"
case "$VARIANT" in glide|tapfilter) ;; *) echo "usage: $0 glide|tapfilter" >&2; exit 2 ;; esac

HERE=$(cd "$(dirname "$0")" && pwd)
PATCH="$HERE/../patches/legion-touchpad-$VARIANT.patch"
URL=https://github.com/ShadowBlip/InputPlumber/archive/refs/tags/v0.84.0.tar.gz
SRC_SHA=64b25d90c3cbabbcfd52e574ff91f64a9bec5ce3b616e36c7179060f29b660bc
IMAGE=docker.io/library/rust:1.92        # the toolchain upstream's own Dockerfile uses
OUT="$HERE/out"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ip-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

for c in podman git curl; do command -v $c >/dev/null || { echo "$c is required" >&2; exit 1; }; done
echo "==> downloading InputPlumber v0.84.0 source"
curl -fsSL -o "$WORK/src.tar.gz" "$URL"
echo "$SRC_SHA  $WORK/src.tar.gz" | sha256sum -c -
tar -xzf "$WORK/src.tar.gz" -C "$WORK"
echo "==> applying $(basename "$PATCH")"
(cd "$WORK/InputPlumber-0.84.0" && git apply --check "$PATCH" && git apply "$PATCH")
mkdir -p "$OUT" "$HERE/.cargo-cache"
echo "==> building in $IMAGE (this takes a few minutes)"
podman run --rm -v "$WORK/InputPlumber-0.84.0:/src:Z" -v "$HERE/.cargo-cache:/usr/local/cargo/registry:Z" -w /src "$IMAGE" \
    sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libclang-dev libudev-dev >/dev/null && cargo build --release --locked'
BIN="$OUT/inputplumber-0.84.0-$VARIANT"
install -m 755 "$WORK/InputPlumber-0.84.0/target/release/inputplumber" "$BIN"
sha256sum "$BIN" | cut -d' ' -f1 > "$BIN.sha256"
"$BIN" --version
echo "==> built $BIN (sha256 $(cat "$BIN.sha256"))"
echo "Install: LG_IP_BINARY=$BIN ./legiongo.sh install precision-touchpad"
