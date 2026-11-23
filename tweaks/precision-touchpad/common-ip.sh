# shellcheck shell=bash
# shellcheck disable=SC2034  # constants used by the scripts that source this file
# precision-touchpad: shared constants (sourced).
IP_VERSION=0.84.0
IP_URL="https://github.com/ShadowBlip/InputPlumber/releases/download/v$IP_VERSION/inputplumber-x86_64.tar.gz"
IP_TARBALL_SHA=1626fb223808bf4dd5f2c9476c8ee6b3803090168f79ee52dcd6fea20252457a   # matches upstream's .sha256.txt
IP_RELEASE_BIN_SHA=b3e6cc3e9193a3f6bead0cd7ee78f580f740658fca52ba61b36055b486cd87ad
IP_FIXED_IN=0.79.2          # first upstream release with the Legion Go touchpad poll-rate fix (PR #702)
IP_DEST="$LG_ROOT/home/legiongo-steamos/inputplumber"
IP_DROPIN_DIR="$LG_ROOT/etc/systemd/system/inputplumber.service.d"
IP_DROPIN="$IP_DROPIN_DIR/50-legiongo-steamos-inputplumber.conf"
# Reference (manual) setup this tweak was extracted from
IP_REF_DROPIN="$IP_DROPIN_DIR/50-legion-desktop-upstream.conf"
IP_REF_DEST="$LG_ROOT/home/inputplumber-upstream"

ip_variant_of() {   # ip_variant_of SHA256 -> human-readable build name
    case "$1" in
        "$IP_RELEASE_BIN_SHA") echo "upstream release v$IP_VERSION" ;;
        2fed277f1c150c32017a2beda653c2e0fecfefac4aa3587a43e68d69daaf6fc9) echo "patched: glide (reference device build)" ;;
        9f3d5c1bafd45d5cc46b67972785dd1f06af8e5fb34289bbcdc285be1af67cd1) echo "patched: tap filter (reference device build)" ;;
        7e22ec5fc98f42e37295719ad736e239d96c8b07d93bea16fd19ca5fe2821627|139ff261f1f96c41e2ed59cc5f7f1907612e0422b88c8e0a3b6f9524a809c459|9e69a3361fa14f4880ed5733105c4689f39e7cafeec87c2569de37327b4059fa|f897fb0e549a896f9303088783e7b95de4bdd27ac94cf0e453dbbfb5da2aa4ec)
            echo "patched: earlier development build" ;;
        "") echo "missing" ;;
        *) echo "custom build" ;;
    esac
}
