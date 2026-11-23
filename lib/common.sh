# shellcheck shell=bash
# Common environment for legiongo.sh and every tweak script.
#
# Environment (all optional):
#   LG_ROOT        prefix for system paths (/etc, /sys, ...). Empty on a real system; tests point it at a mock tree.
#   LG_STATE       install-state directory (default: ${XDG_STATE_HOME:-~/.local/state}/legiongo-steamos)
#   LG_ASSUME_YES  1 = answer "yes" to confirmations (set by --yes)
#   LG_FORCE       1 = allow installing on an untested SteamOS version (set by --force)
#   LG_TEST        1 = test mode: "root" operations run without sudo inside the mock tree

LG_REPO=${LG_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
LG_ROOT=${LG_ROOT:-}
LG_STATE=${LG_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/legiongo-steamos}
LG_ASSUME_YES=${LG_ASSUME_YES:-0}
LG_FORCE=${LG_FORCE:-0}
LG_TEST=${LG_TEST:-0}
export LG_REPO LG_ROOT LG_STATE LG_ASSUME_YES LG_FORCE LG_TEST

# shellcheck source=lib/logging.sh
. "$LG_REPO/lib/logging.sh"
# shellcheck source=lib/detection.sh
. "$LG_REPO/lib/detection.sh"
# shellcheck source=lib/backup.sh
. "$LG_REPO/lib/backup.sh"

# ---------------------------------------------------------------- manifest.json access
lg_json() {   # lg_json FILE JQ_FILTER   (jq ships with SteamOS; python3 fallback)
    if command -v jq >/dev/null 2>&1; then
        jq -r "$2 // empty" "$1"
    else
        python3 -I - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
f = sys.argv[2].lstrip(".")
v = d
for part in f.replace("[]", "").split("."):
    v = v.get(part) if isinstance(v, dict) else None
if isinstance(v, list): print("\n".join(map(str, v)))
elif v is not None: print(str(v).lower() if isinstance(v, bool) else v)
PY
    fi
}
lg_tweak_dir() { printf '%s/tweaks/%s' "$LG_REPO" "$1"; }
lg_mf() { lg_json "$(lg_tweak_dir "${2:-$LG_TWEAK}")/manifest.json" "$1"; }

# ---------------------------------------------------------------- confirmations
lg_confirm() {   # lg_confirm "question"  -> 0 = yes
    [ "$LG_ASSUME_YES" = 1 ] && return 0
    if [ ! -t 0 ]; then
        lg_warn "no terminal to ask: \"$1\" (use --yes to confirm non-interactively)"
        return 1
    fi
    local a
    read -r -p "  $1 [y/N] " a
    case "$a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------- check.sh helpers
# check.sh scripts print human-readable lines and finish with exactly one line
#   RESULT=<state> <detail>
# state: not-installed | installed | partial | external | conflict | incompatible | untested | upstream-equivalent
#   upstream-equivalent: the stock SteamOS software already provides what this tweak would install
#   (feature-level check, not a version comparison); the tweak stays available.
LG_FAIL=0; LG_UNTESTED=0
lg_req() {   # lg_req "description" command...   (hard requirement)
    local d="$1"; shift
    if "$@" >/dev/null 2>&1; then lg_ok "$d"; else lg_error "$d"; LG_FAIL=1; fi
}
lg_req_soft() {   # lg_req_soft "description" command...   (warning only)
    local d="$1"; shift
    if "$@" >/dev/null 2>&1; then lg_ok "$d"; else lg_warn "$d"; fi
}

# Platform checks driven by manifest.json:
#   "hardware": "legion-go"  -> requires the Lenovo Legion Go (DMI); other devices are incompatible
#               "capability" -> any device; the tweak's own check.sh probes the interfaces it needs
#               "portable"   -> any SteamOS device (software-only)
#   "version_policy": "tested" -> SteamOS versions outside tested_steamos need --force
#                     "feature"  -> other versions only warn; feature probes decide compatibility
lg_check_platform() {
    local hw policy v tested
    hw=$(lg_mf .hardware); hw=${hw:-legion-go}
    policy=$(lg_mf .version_policy); policy=${policy:-tested}
    if lg_is_legion_go; then lg_ok "device: $(lg_device_desc) (reference hardware)"
    elif [ "$hw" = legion-go ]; then
        lg_error "device: $(lg_device_desc): this tweak drives Lenovo Legion Go hardware and is unavailable here"; LG_FAIL=1
    else
        lg_info "device: $(lg_device_desc) — $hw tweak: allowed when the required capabilities are found (untested on this device)"
    fi
    if lg_is_steamos; then
        v=$(lg_os_version); tested=$(lg_mf '.tested_steamos[]' | tr '\n' ' ')
        if lg_version_in "$v" "$tested"; then lg_ok "SteamOS $v (tested)"
        elif [ "$policy" = feature ]; then lg_warn "SteamOS $v is not in the tested list ($tested); feature checks below decide"
        else lg_warn "SteamOS $v has not been tested with this tweak (tested: $tested)"; LG_UNTESTED=1; fi
    else
        lg_error "operating system: $(lg_os_field PRETTY_NAME) is not SteamOS"; LG_FAIL=1
    fi
}

lg_check_result() {   # lg_check_result EXTERNAL(0|1) [CONFLICT_REASON] [EXTERNAL_DETAIL]
    local external="$1" conflict="${2:-}" detail="${3:-}" mode
    if lg_is_tracked_tweak; then
        mode=$(lg_state_get mode)
        if lg_verify_manifest; then
            echo "RESULT=installed ${mode:-installed} v$(lg_state_get version)"
        else
            echo "RESULT=partial recorded files are missing or changed (see warnings)"
        fi
    elif [ -n "$conflict" ]; then echo "RESULT=conflict $conflict"
    elif [ "$external" = 1 ]; then echo "RESULT=external ${detail:-an equivalent manual setup was found}"
    elif [ "$LG_FAIL" = 1 ]; then echo "RESULT=incompatible requirements not met on this device"
    elif [ "$LG_UNTESTED" = 1 ]; then echo "RESULT=untested SteamOS version not tested (use --force to install anyway)"
    else echo "RESULT=not-installed ready to install"
    fi
}

# Called at the start of install.sh / adopt.sh
lg_begin() {   # lg_begin installed|adopted
    lg_state_set mode "$1"
    lg_state_set version "$(lg_mf .version)"
    lg_state_set installed_at "$(date -Is)"
    lg_state_set repo_commit "$(git -C "$LG_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    lg_log "begin $1 v$(lg_mf .version)"
}

# Tweak scripts are run by legiongo.sh with LG_TWEAK set.
[ -n "${LG_TWEAK:-}" ] && export LG_TWEAK

# ---------------------------------------------------------------- verify.sh helpers
# verify.sh exit codes: 0 = works, 1 = broken (install is rolled back), 2 = cannot be checked right now
# (e.g. not inside Desktop Mode, Steam not running). LG_VERIFY_QUICK=1 (used by `status`) skips waiting.
lg_verify_timeout() { [ "${LG_VERIFY_QUICK:-0}" = 1 ] && echo 1 || echo "${1:-15}"; }
lg_wait_for() {   # lg_wait_for SECONDS command...   -> 0 as soon as the command succeeds
    local end=$(( $(date +%s) + $1 )); shift
    while :; do "$@" >/dev/null 2>&1 && return 0; [ "$(date +%s)" -ge "$end" ] && return 1; sleep 1; done
}
lg_unit_of() {   # lg_unit_of user|root -> unit names recorded by this tweak's manifest
    local m; m=$(lg_manifest); [ -r "$m" ] || return 0
    awk -F'\t' -v o="$1" '$1 == "unit" && $3 == o {print $2}' "$m"
}
# Active and not restarting: NRestarts unchanged over 3 seconds (catches crash loops that look "active").
lg_unit_stable() {   # lg_unit_stable user|root UNIT
    local r1 r2
    lg_systemctl "$1" is-active --quiet "$2" || return 1
    [ "${LG_VERIFY_QUICK:-0}" = 1 ] && return 0
    r1=$(lg_systemctl "$1" show -p NRestarts --value "$2" 2>/dev/null)
    sleep "${LG_VERIFY_SETTLE:-3}"
    r2=$(lg_systemctl "$1" show -p NRestarts --value "$2" 2>/dev/null)
    lg_systemctl "$1" is-active --quiet "$2" && [ "$r1" = "$r2" ]
}
lg_unit_logged() {   # lg_unit_logged user|root UNIT REGEX   (since the unit's current start)
    local since
    since=$(lg_systemctl "$1" show -p ActiveEnterTimestamp --value "$2" 2>/dev/null)
    if [ "$1" = root ]; then journalctl -u "$2" ${since:+--since "$since"} --no-pager -o cat 2>/dev/null | grep -Eq "$3"
    else journalctl --user -u "$2" ${since:+--since "$since"} --no-pager -o cat 2>/dev/null | grep -Eq "$3"; fi
}
