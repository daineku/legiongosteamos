#!/bin/bash
# Lightweight test suite. Never touches the real system: every install test runs with a sandbox
# HOME, a mock system root (LG_ROOT), stub commands (systemctl, kwriteconfig6, pactl, ...) and LG_TEST=1.
#   tests/run-tests.sh            all tests
#   tests/run-tests.sh static     static checks only
set -uo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/tests/stubs.sh"
PASS=0; FAIL=0; SKIP=0
pass() { PASS=$((PASS + 1)); printf '  PASS %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '  SKIP %s\n' "$*"; }
t() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi; }
tn() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi; }

# ---------------------------------------------------------------- A. static validation
static_tests() {
    echo "== A. static validation"
    local f bad=0
    while IFS= read -r f; do bash -n "$f" || { bad=1; echo "    syntax: $f"; }; done < <(find "$REPO" -name '*.sh' -not -path '*/.sandbox*' | sort)
    [ "$bad" = 0 ] && pass "bash syntax of all scripts" || fail "bash syntax"
    bad=0
    while IFS= read -r f; do python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$f" || { bad=1; echo "    python: $f"; }; done \
        < <(find "$REPO/tweaks" -name '*.py' -o -name '*.py.in' | sort)
    [ "$bad" = 0 ] && pass "python syntax" || fail "python syntax"
    bad=0
    for f in "$REPO"/tweaks/*/manifest.json; do
        jq -e '.id and .name and .version and .status and .scope and (.requires_root|type=="boolean") and (.depends|type=="array") and (.tested_steamos|type=="array") and .summary and .restart' "$f" >/dev/null \
            || { bad=1; echo "    manifest: $f"; }
        [ "$(jq -r .id "$f")" = "$(basename "$(dirname "$f")")" ] || { bad=1; echo "    id mismatch: $f"; }
        case "$(jq -r .status "$f")" in "Reference Verified"|Experimental) ;; *) bad=1; echo "    status: $f" ;; esac
        for d in $(jq -r '.depends[]' "$f"); do [ -f "$REPO/tweaks/$d/manifest.json" ] || { bad=1; echo "    unknown dependency $d in $f"; }; done
    done
    [ "$bad" = 0 ] && pass "manifest.json schema, ids, statuses, dependencies" || fail "manifests"
    bad=0
    for d in "$REPO"/tweaks/*/; do
        for s in README.md manifest.json check.sh install.sh uninstall.sh; do [ -f "$d$s" ] || { bad=1; echo "    missing $d$s"; }; done
        for s in check.sh install.sh uninstall.sh adopt.sh status.sh; do [ -f "$d$s" ] && [ ! -x "$d$s" ] && { bad=1; echo "    not executable: $d$s"; }; done
        for h in "## What It Does" "## Why You Need It" "## Before vs After" "## How It Improves Legion Go" \
                 "## Install — One Command" "## Uninstall — One Command" "## How to Check It Works" "## Dependencies" \
                 "## Compatibility" "## Known Limitations"; do
            grep -qF "$h" "$d/README.md" 2>/dev/null || { bad=1; echo "    $d/README.md lacks '$h'"; }
        done
    done
    [ "$bad" = 0 ] && pass "tweak structure, permissions and README sections" || fail "tweak structure"
    # Shared lib must not depend on any tweak; tweaks must not reference each other's files.
    bad=0
    for d in "$REPO"/tweaks/*/; do
        id=$(basename "$d")
        if grep -rhoE 'tweaks/[a-z-]+/' "$d" --include='*.sh' | grep -v "tweaks/$id/" | grep -q .; then bad=1; echo "    $id references another tweak"; fi
    done
    [ "$bad" = 0 ] && pass "module isolation (no cross-tweak file references)" || fail "module isolation"
    if command -v shellcheck >/dev/null; then
        t "shellcheck (warnings and errors)" shellcheck -x -S warning "$REPO/legiongo.sh" "$REPO"/lib/*.sh "$REPO"/tweaks/*/*.sh "$REPO"/tweaks/*/build/*.sh "$REPO"/tests/*.sh
    elif [ -n "${LG_SHELLCHECK_IMAGE:-}" ] && command -v podman >/dev/null; then
        local files
        files=$(cd "$REPO" && ls legiongo.sh lib/*.sh tweaks/*/*.sh tweaks/*/build/*.sh tests/*.sh experimental/*/*.sh)
        # shellcheck disable=SC2086  # word splitting of the file list is intended
        t "shellcheck via $LG_SHELLCHECK_IMAGE (warnings and errors)" podman run --rm -v "$REPO:/mnt:Z" -w /mnt "$LG_SHELLCHECK_IMAGE" -x -S warning $files
    else
        skip "shellcheck not installed (set LG_SHELLCHECK_IMAGE=docker.io/koalaman/shellcheck:stable to use podman)"
    fi
    secret_scan
}

secret_scan() {
    local hits p LOCAL_PATTERNS=()
    # Personal strings to block (your e-mail, Wi-Fi names, device IDs) go in tests/secret-patterns.local,
    # one extended regex per line. That file is git-ignored so the patterns themselves are never published.
    if [ -r "$REPO/tests/secret-patterns.local" ]; then
        while IFS= read -r p; do [ -n "$p" ] && LOCAL_PATTERNS+=(-e "$p"); done < "$REPO/tests/secret-patterns.local"
    fi
    hits=$(cd "$REPO" && git ls-files -co --exclude-standard 2>/dev/null | grep -v -e '^tests/run-tests.sh$' -e '^tests/secret-patterns.local$' | xargs -r grep -nIE \
        -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' -e 'gh[pousr]_[A-Za-z0-9]{30,}' -e 'github_pat_[A-Za-z0-9_]{20,}' \
        -e 'AKIA[0-9A-Z]{16}' -e 'xox[abp]-[0-9A-Za-z-]{10,}' -e '(psk|password|passwd|secret|token)[[:space:]]*=[[:space:]]*[^[:space:]$"]{6,}' \
        -e '/home/deck/' ${LOCAL_PATTERNS[@]+"${LOCAL_PATTERNS[@]}"} 2>/dev/null)
    if [ -z "$hits" ]; then pass "secret / personal-data scan"; else fail "secret / personal-data scan"; printf '%s\n' "$hits" | sed 's/^/    /'; fi
}

# ---------------------------------------------------------------- B. simulated installs
SANDBOX=""
new_sandbox() {   # new_sandbox [steamos-version] [product]
    SANDBOX=$(mktemp -d "$REPO/tests/.sandbox.XXXXXX")
    export SANDBOX HOME="$SANDBOX/home" LG_ROOT="$SANDBOX/root" LG_TEST=1 LG_STATE="$SANDBOX/home/.local/state/legiongo-steamos"
    export XDG_STATE_HOME="$SANDBOX/home/.local/state" XDG_CURRENT_DESKTOP=KDE NO_COLOR=1
    mkdir -p "$HOME/.local/share/Steam" "$HOME/.config"
    make_root "$LG_ROOT" "${1:-3.9.5}" "${2:-83E1}"
    make_stubs "$SANDBOX/bin"
    export PATH="$SANDBOX/bin:$ORIG_PATH"
}
lg() { "$REPO/legiongo.sh" "$@" < /dev/null; }
state_of() { lg check "$1" | sed -n 's/^RESULT=\([a-z-]*\).*/\1/p'; }
mf_lines() { wc -l < "$LG_STATE/$1/manifest.tsv"; }
ORIG_PATH=$PATH

sim_tests() {
    echo "== B. simulated installation tests (sandbox)"
    new_sandbox
    t "list runs" lg list
    t "info runs" lg info steam-keyboard
    t "unknown tweak rejected" bash -c "! $REPO/legiongo.sh install nope"

    # --- steam-keyboard: install, idempotency, uninstall
    t "steam-keyboard: not-installed before install" test "$(state_of steam-keyboard)" = not-installed
    t "steam-keyboard: install (--yes creates the debugger flag)" lg install steam-keyboard --yes
    t "steam-keyboard: state installed" test "$(state_of steam-keyboard)" = installed
    t "steam-keyboard: files installed" test -f "$HOME/.local/lib/legiongo-steamos/steam-keyboard/lgk-inject.js"
    t "steam-keyboard: unit enabled" grep -q "systemctl --user enable legiongo-steam-keyboard.service" "$SANDBOX/calls.log"
    t "steam-keyboard: KWin rule added" grep -q 'kwinrulesrc|General|rules=legiongo-osk-layer' "$SANDBOX/kconfig.db"
    n=$(mf_lines steam-keyboard)
    t "steam-keyboard: re-install" lg install steam-keyboard --yes
    t "steam-keyboard: re-install is idempotent (no duplicate records)" test "$(mf_lines steam-keyboard)" = "$n"
    t "steam-keyboard: KWin rule not duplicated" test "$(grep 'kwinrulesrc|General|rules=' "$SANDBOX/kconfig.db" | tail -1)" = 'kwinrulesrc|General|rules=legiongo-osk-layer'
    echo "# my edit" >> "$HOME/.config/systemd/user/legiongo-steam-keyboard.service"
    t "steam-keyboard: partial detected after user edit" test "$(state_of steam-keyboard)" = partial
    lg uninstall steam-keyboard >/dev/null 2>&1
    t "steam-keyboard: uninstall keeps the user-edited unit" test -f "$HOME/.config/systemd/user/legiongo-steam-keyboard.service"
    t "steam-keyboard: uninstall removed unchanged files" test ! -e "$HOME/.local/lib/legiongo-steamos/steam-keyboard/lgk-helper.py"
    t "steam-keyboard: KWin rule removed" bash -c "! grep -q 'legiongo-osk-layer' '$SANDBOX/kconfig.db'"
    t "steam-keyboard: debugger flag removed (created by us, no Decky)" test ! -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
    t "steam-keyboard: state archived" test -d "$LG_STATE/.uninstalled"
    rm -f "$HOME/.config/systemd/user/legiongo-steam-keyboard.service"

    # --- no flag creation without --yes; shared debugger flag is reference counted
    new_sandbox
    t "steam-keyboard: install refused without confirmation (no tty, flag missing)" bash -c "! $REPO/legiongo.sh install steam-keyboard < /dev/null"
    t "steam-keyboard: failed install rolled back" test ! -e "$HOME/.local/lib/legiongo-steamos/steam-keyboard/lgk-helper.py"
    mkdir -p "$HOME/homebrew/services"; touch "$HOME/homebrew/services/PluginLoader"
    lg install steam-keyboard --yes >/dev/null 2>&1; lg uninstall steam-keyboard >/dev/null 2>&1
    t "steam-keyboard: debugger flag kept when an unmanaged Decky Loader is present" test -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging"

    # --- optional Russian layout is restored
    new_sandbox; touch "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
    "$SANDBOX/bin/kwriteconfig6" --file kxkbrc --group Layout --key LayoutList us
    LG_KEYBOARD_LAYOUTS="ru de us(intl)" lg install steam-keyboard >/dev/null 2>&1
    t "steam-keyboard: LG_KEYBOARD_LAYOUTS adds layouts and variants" test "$(kreadconfig6 --file kxkbrc --group Layout --key LayoutList)|$(kreadconfig6 --file kxkbrc --group Layout --key VariantList)" = "us,ru,de,us|,,,intl"
    t "steam-keyboard: invalid layout code rejected" bash -c "! LG_KEYBOARD_LAYOUTS='ru;rm' $REPO/legiongo.sh install steam-keyboard < /dev/null >/dev/null 2>&1 || ! grep -q 'rm' '$SANDBOX/kconfig.db'"
    lg uninstall steam-keyboard >/dev/null 2>&1
    t "steam-keyboard: layout list restored" test "$(kreadconfig6 --file kxkbrc --group Layout --key LayoutList)" = "us"
    t "steam-keyboard: pre-existing debugger flag untouched" test -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging"

    # --- external setup detection and adoption
    new_sandbox
    mkdir -p "$HOME/.local/lib/legion-desktop-build/lgk" "$HOME/.config/systemd/user"
    cp "$REPO"/tweaks/steam-keyboard/files/lgk-*.js "$REPO/tweaks/steam-keyboard/files/lgk-helper.py" "$HOME/.local/lib/legion-desktop-build/lgk/"
    echo "[Unit]" > "$HOME/.config/systemd/user/lgk-helper.service"
    t "steam-keyboard: external setup detected" test "$(state_of steam-keyboard)" = external
    t "steam-keyboard: install refuses over external setup" bash -c "! $REPO/legiongo.sh install steam-keyboard --yes"
    t "steam-keyboard: uninstall refuses unmanaged setup" bash -c "! $REPO/legiongo.sh uninstall steam-keyboard"
    before=$(find "$HOME" -type f -not -path "*/.local/state/*" -exec sha256sum {} + | sort)
    t "steam-keyboard: adopt" lg adopt steam-keyboard
    after=$(find "$HOME" -type f -not -path "*/.local/state/*" -exec sha256sum {} + | sort)
    t "steam-keyboard: adopt changed no files" test "$before" = "$after"
    t "steam-keyboard: adopted state reported as installed" test "$(state_of steam-keyboard)" = installed
    t "steam-keyboard: uninstall of adopted setup" lg uninstall steam-keyboard
    t "steam-keyboard: adopted files removed" test ! -e "$HOME/.local/lib/legion-desktop-build/lgk/lgk-helper.py"
    t "steam-keyboard: adopted unit disabled" grep -q "disable --now lgk-helper.service" "$SANDBOX/calls.log"

    # --- unsupported / untested environments
    new_sandbox 3.9.5 21XX
    t "unsupported device -> precision-touchpad incompatible" test "$(state_of precision-touchpad)" = incompatible
    t "unsupported device -> install refused" bash -c "! $REPO/legiongo.sh install desktop-touchpad --yes"
    new_sandbox 3.10.0
    t "untested SteamOS -> state untested" test "$(state_of desktop-touchpad)" = untested
    t "untested SteamOS -> install needs --force" bash -c "! $REPO/legiongo.sh install mic-enhance"
    t "untested SteamOS -> --force installs" lg install mic-enhance --force
    # --- precision-touchpad: feature-level detection, not version numbers
    new_sandbox
    t "precision-touchpad: stock 0.78 path -> installable" test "$(state_of precision-touchpad)" = not-installed
    sed -i 's/interface_num: 2/interface_num: 1/' "$LG_ROOT/usr/share/inputplumber/devices/50-legion_go.yaml"
    t "native stock driver + release variant -> upstream-equivalent" test "$(LG_IP_VARIANT=release state_of precision-touchpad)" = upstream-equivalent
    t "native stock driver + glide variant -> still installable (tap filter)" test "$(state_of precision-touchpad)" = not-installed
    t "newer stock InputPlumber -> conflict (no downgrade)" test "$(STUB_IP_VERSION=0.90.0 state_of precision-touchpad)" = conflict
    t "unknown variant rejected" test "$(LG_IP_VARIANT=fast state_of precision-touchpad)" = incompatible

    # --- dependency handling
    new_sandbox
    t "desktop-touchpad: dependency not installed without permission" bash -c "! $REPO/legiongo.sh install desktop-touchpad < /dev/null"
    t "desktop-touchpad: nothing installed after refusal" test ! -e "$LG_STATE/desktop-touchpad/state"
    sed -i 's/interface_num: 2/interface_num: 1/' "$LG_ROOT/usr/share/inputplumber/devices/50-legion_go.yaml"
    t "desktop-touchpad: installs when stock InputPlumber already has the native driver" bash -c "STUB_IP_VERSION=0.90.0 $REPO/legiongo.sh install desktop-touchpad < /dev/null"
    t "desktop-touchpad: KDE tap-to-click off for the native pad" grep -q 'InputPlumber Touchpad|TapToClick=false' "$SANDBOX/kconfig.db"
    lg uninstall desktop-touchpad >/dev/null 2>&1
    t "desktop-touchpad: tap setting removed again" bash -c "! grep -q 'TapToClick' '$SANDBOX/kconfig.db'"

    # --- mic-enhance
    new_sandbox
    t "mic-enhance: install" lg install mic-enhance
    t "mic-enhance: node templated" grep -q 'target.object  = "alsa_input.pci-0000_c2_00.6.analog-stereo"' "$HOME/.config/pipewire/filter-chain.conf.d/60-legiongo-mic-enhance.conf"
    t "mic-enhance: default source set" test "$(pactl get-default-source)" = legiongo_mic_enhanced
    lg uninstall mic-enhance >/dev/null 2>&1
    t "mic-enhance: default source restored" test "$(pactl get-default-source)" = default_mic
    t "mic-enhance: conf removed" test ! -e "$HOME/.config/pipewire/filter-chain.conf.d/60-legiongo-mic-enhance.conf"

    # --- desktop-power-policy (root files inside the mock root)
    new_sandbox
    t "power: install" lg install desktop-power-policy
    t "power: user home templated" grep -q "STEAM_PID_DIR = \"$HOME/.steam\"" "$LG_ROOT/etc/legion-power/legion-power-policy.py"
    t "power: no sudo used in test mode" bash -c "! grep -q UNEXPECTED '$SANDBOX/calls.log'"
    echo performance > "$LG_ROOT/sys/class/platform-profile/platform-profile-0/profile"
    lg uninstall desktop-power-policy >/dev/null 2>&1
    t "power: files removed" test ! -e "$LG_ROOT/etc/legion-power/legion-power-policy.py"
    t "power: empty /etc/legion-power removed" test ! -d "$LG_ROOT/etc/legion-power"
    t "power: firmware profile restored" test "$(cat "$LG_ROOT/sys/class/platform-profile/platform-profile-0/profile")" = custom

    # --- precision-touchpad with the real upstream release archive (if cached locally)
    if [ -n "${LG_TEST_IP_TARBALL:-}" ] && [ -r "$LG_TEST_IP_TARBALL" ]; then
        new_sandbox
        t "precision-touchpad: release variant install from verified archive" env LG_IP_VARIANT=release LG_IP_TARBALL="$LG_TEST_IP_TARBALL" "$REPO/legiongo.sh" install precision-touchpad
        t "precision-touchpad: binary checksum" test "$(sha256sum "$LG_ROOT/home/legiongo-steamos/inputplumber/bin/inputplumber" | cut -d' ' -f1)" = b3e6cc3e9193a3f6bead0cd7ee78f580f740658fca52ba61b36055b486cd87ad
        t "precision-touchpad: drop-in points to launcher" grep -q '^ExecStart=/home/legiongo-steamos/inputplumber/bin/inputplumber-launch' "$LG_ROOT/etc/systemd/system/inputplumber.service.d/50-legiongo-steamos-inputplumber.conf"
        n=$(mf_lines precision-touchpad)
        env LG_IP_VARIANT=release LG_IP_TARBALL="$LG_TEST_IP_TARBALL" "$REPO/legiongo.sh" install precision-touchpad >/dev/null 2>&1
        t "precision-touchpad: re-install idempotent" test "$(mf_lines precision-touchpad)" = "$n"
        t "precision-touchpad: uninstall" lg uninstall precision-touchpad
        t "precision-touchpad: tree and drop-in removed" bash -c "[ ! -e '$LG_ROOT/home/legiongo-steamos' ] && [ ! -e '$LG_ROOT/etc/systemd/system/inputplumber.service.d' ]"
        new_sandbox; touch "$SANDBOX/fail-active"
        t "precision-touchpad: failing service start is rolled back" bash -c "! LG_IP_VARIANT=release LG_IP_TARBALL='$LG_TEST_IP_TARBALL' $REPO/legiongo.sh install precision-touchpad"
        t "precision-touchpad: nothing left after rollback" bash -c "[ ! -e '$LG_ROOT/etc/systemd/system/inputplumber.service.d/50-legiongo-steamos-inputplumber.conf' ] && [ ! -e '$LG_ROOT/home/legiongo-steamos' ]"
    else
        skip "precision-touchpad install (set LG_TEST_IP_TARBALL=<inputplumber-x86_64.tar.gz v0.84.0>)"
    fi

    # --- precision-touchpad patched variants (needs the release archive + locally built patched binaries)
    if [ -n "${LG_TEST_IP_TARBALL:-}" ] && [ -r "$REPO/tweaks/precision-touchpad/build/out/inputplumber-0.84.0-tapfilter" ]; then
        new_sandbox
        t "precision-touchpad: tapfilter variant install (checksum-pinned binary)" env LG_IP_TARBALL="$LG_TEST_IP_TARBALL" LG_IP_VARIANT=tapfilter LG_IP_PATCHED_DIR="$REPO/tweaks/precision-touchpad/build/out" "$REPO/legiongo.sh" install precision-touchpad
        t "precision-touchpad: tapfilter binary installed" test "$(sha256sum "$LG_ROOT/home/legiongo-steamos/inputplumber/bin/inputplumber" | cut -d' ' -f1)" = 9f3d5c1bafd45d5cc46b67972785dd1f06af8e5fb34289bbcdc285be1af67cd1
        t "precision-touchpad: update is a no-op when current" bash -c "LG_IP_TARBALL='$LG_TEST_IP_TARBALL' LG_IP_VARIANT=tapfilter LG_IP_PATCHED_DIR='$REPO/tweaks/precision-touchpad/build/out' $REPO/legiongo.sh update precision-touchpad | grep 'up to date' >/dev/null"
        new_sandbox
        mkdir -p "$SANDBOX/badout"; echo junk > "$SANDBOX/badout/inputplumber-0.84.0-glide"
        t "precision-touchpad: wrong patched binary rejected by checksum" bash -c "! LG_IP_TARBALL='$LG_TEST_IP_TARBALL' LG_IP_PATCHED_DIR='$SANDBOX/badout' $REPO/legiongo.sh install precision-touchpad"
        t "precision-touchpad: nothing left after rejected binary" test ! -e "$LG_ROOT/home/legiongo-steamos"
    else
        skip "precision-touchpad variants (needs LG_TEST_IP_TARBALL and build/out binaries)"
    fi

    # --- update command
    new_sandbox
    lg install mic-enhance >/dev/null 2>&1
    t "update: current tweak reports up to date" bash -c "$REPO/legiongo.sh update mic-enhance | grep 'up to date' >/dev/null"
    sed -i 's/^version=.*/version=0.9.0/' "$LG_STATE/mic-enhance/state"
    t "update: older installed version is updated" bash -c "$REPO/legiongo.sh update mic-enhance | grep 'v0.9.0 -> v' >/dev/null"
    t "update: version recorded after update" test "$(sed -n 's/^version=//p' "$LG_STATE/mic-enhance/state")" = "$(jq -r .version "$REPO/tweaks/mic-enhance/manifest.json")"
    t "update: does not touch other tweaks" test ! -e "$LG_STATE/steam-keyboard/state"
    t "update: refuses tweaks that are not installed" bash -c "! $REPO/legiongo.sh update desktop-touchpad"
    t "doctor runs and prints no home path" bash -c "out=\$($REPO/legiongo.sh doctor 2>&1) && ! printf '%s' \"\$out\" | grep -q \"$HOME\""

    # --- decky-loader + decky-power-plugins (real pinned release files, if cached locally)
    if [ -n "${LG_TEST_DECKY_BINARY:-}" ] && [ -r "${LG_TEST_SDTDP_ZIP:-/nonexistent}" ] && [ -r "${LG_TEST_LGR_TARBALL:-/nonexistent}" ]; then
        new_sandbox
        export LG_DECKY_BINARY="$LG_TEST_DECKY_BINARY" LG_SDTDP_ZIP="$LG_TEST_SDTDP_ZIP" LG_LGR_TARBALL="$LG_TEST_LGR_TARBALL"
        t "decky-power-plugins: dependency refused without permission" bash -c "! $REPO/legiongo.sh install decky-power-plugins < /dev/null"
        t "decky-power-plugins: nothing installed after refusal" test ! -e "$HOME/homebrew/services/PluginLoader"
        t "decky-power-plugins: installs with its dependency (--yes)" lg install decky-power-plugins --yes
        t "decky-loader: pinned binary installed" test "$(sha256sum "$HOME/homebrew/services/PluginLoader" | cut -d' ' -f1)" = 7bb73b0502c49e7194f34f9ce4ddb6777764e9277d7a5e54665f66460d50c315
        t "decky-loader: unit templated with the user's home" grep -q "^ExecStart=$HOME/homebrew/services/PluginLoader" "$LG_ROOT/etc/systemd/system/plugin_loader.service"
        t "decky-power-plugins: safety patch applied" grep -q 'legiongo-steamos: build the curve' "$HOME/homebrew/plugins/LegionGoRemapper/main.py"
        t "decky-power-plugins: safe settings seeded" grep -q '"supportsRyzenadjCoall": false' "$HOME/homebrew/settings/SimpleDeckyTDP/settings.json"
        t "decky-loader: refuses uninstall while plugins depend on it" bash -c "! $REPO/legiongo.sh uninstall decky-loader"
        lg install steam-keyboard >/dev/null 2>&1
        t "shared flag: held by decky-loader and steam-keyboard" test "$(grep -c -v preexisting "$LG_STATE/.shared/steam-debugger")" = 2
        lg uninstall steam-keyboard >/dev/null 2>&1
        t "shared flag: kept while decky-loader still needs it" test -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
        lg uninstall decky-power-plugins >/dev/null 2>&1; lg uninstall decky-loader >/dev/null 2>&1
        t "shared flag: removed after the last holder (created by us)" test ! -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
        t "decky: plugins, binary and unit removed" bash -c "[ ! -e '$HOME/homebrew/plugins/SimpleDeckyTDP/main.py' ] && [ ! -e '$HOME/homebrew/services/PluginLoader' ] && [ ! -e '$LG_ROOT/etc/systemd/system/plugin_loader.service' ]"
        # transactional rollback: dependency installed in the same command is undone when the main tweak fails
        new_sandbox
        export LG_LGR_TARBALL="$SANDBOX/corrupt.tar.gz"; echo corrupt > "$LG_LGR_TARBALL"
        t "transaction: failing plugin install fails" bash -c "! $REPO/legiongo.sh install decky-power-plugins --yes"
        t "transaction: dependency installed in the same command rolled back" test ! -e "$HOME/homebrew/services/PluginLoader"
        unset LG_DECKY_BINARY LG_SDTDP_ZIP LG_LGR_TARBALL
    else
        skip "decky modules (set LG_TEST_DECKY_BINARY, LG_TEST_SDTDP_ZIP, LG_TEST_LGR_TARBALL)"
    fi

    # --- Multilingual Input Support: helper logic (pure functions, no D-Bus)
    t "multilingual: helper layout matching and language report" python3 -I "$REPO/tests/test_lgk_helper.py" "$REPO/tweaks/steam-keyboard/files/lgk-helper.py"

    # --- library: replacing a pre-existing file and restoring it
    new_sandbox
    ( export LG_TWEAK=libtest; . "$REPO/lib/common.sh"
      echo original > "$HOME/f"; chmod 600 "$HOME/f"; echo new > "$SANDBOX/src"
      lg_put_file "$SANDBOX/src" "$HOME/f" 644 user; lg_rollback ) >/dev/null 2>&1
    t "lib: replaced file restored with original content" test "$(cat "$HOME/f")" = original
    t "lib: replaced file restored with original mode" test "$(stat -c %a "$HOME/f")" = 600
}

case "${1:-all}" in
    static) static_tests ;;
    *) static_tests; sim_tests ;;
esac
rm -rf "$REPO"/tests/.sandbox.*
echo
echo "passed: $PASS  failed: $FAIL  skipped: $SKIP"
[ "$FAIL" = 0 ]
