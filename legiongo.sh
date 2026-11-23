#!/bin/bash
# Legion Go SteamOS — Compatibility & Tweaks: command-line installer.
# Runs only when you call it. Nothing here stays running in the background.
set -uo pipefail

LG_REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
export LG_REPO
# shellcheck source=lib/common.sh
. "$LG_REPO/lib/common.sh"

usage() {
    cat <<EOF
Legion Go SteamOS — Compatibility & Tweaks

Usage: ./legiongo.sh <command> [tweak-id] [options]

Commands:
  list                    List all tweaks with their status on this device
  info <tweak>            Show what a tweak does, its requirements and status
  check <tweak>           Check requirements and detect existing installations (changes nothing)
  install <tweak>         Install one tweak (asks before installing any dependency)
  status [tweak]          Show the installed state of one tweak, or of all tweaks
  uninstall <tweak>       Remove a tweak and restore what it changed
  adopt <tweak>           Record an equivalent setup that is already on this device, without
                          changing it, so that status/uninstall can manage it
  help                    Show this help

Options:
  --yes                   Answer "yes" to confirmation questions
  --force                 Allow installing on a SteamOS version the tweak was not tested on

State and backups: $LG_STATE
EOF
}

tweak_ids() { for d in "$LG_REPO"/tweaks/*/manifest.json; do basename "$(dirname "$d")"; done; }
require_tweak() {
    [ -n "${1:-}" ] || { usage; exit 2; }
    [ -f "$LG_REPO/tweaks/$1/manifest.json" ] || lg_die "unknown tweak '$1' (see ./legiongo.sh list)"
}

# Run one of a tweak's scripts in a child shell with LG_TWEAK set.
run_script() {   # run_script TWEAK SCRIPT [ARGS...]
    local t="$1" s="$2"; shift 2
    LG_TWEAK="$t" bash "$LG_REPO/tweaks/$t/$s" "$@"
}

# check.sh result state ("installed", "external", ...) and detail
check_state() {   # check_state TWEAK [quiet]
    local out
    out=$(run_script "$1" check.sh 2>&1)
    CHECK_OUTPUT="$out"
    CHECK_LINE=$(printf '%s\n' "$out" | sed -n 's/^RESULT=//p' | tail -1)
    CHECK_STATE=${CHECK_LINE%% *}
    CHECK_DETAIL=${CHECK_LINE#* }
    [ -n "$CHECK_STATE" ] || { CHECK_STATE=error; CHECK_DETAIL="check.sh produced no result"; }
}

dep_satisfied() {   # installed by us, adopted, or present externally
    check_state "$1"
    case "$CHECK_STATE" in installed|external|not-needed) return 0 ;; esac
    return 1
}

cmd_list() {
    printf '%-22s %-20s %-30s %s\n' "TWEAK" "STATUS" "SCOPE" "ON THIS DEVICE"
    local t
    for t in $(tweak_ids); do
        check_state "$t"
        printf '%-22s %-20s %-30s %s\n' "$t" "$(lg_mf .status "$t")" "$(lg_mf .scope "$t")" "$CHECK_STATE"
    done
    echo
    echo "Details: ./legiongo.sh info <tweak>"
}

cmd_info() {
    require_tweak "$1"
    local t="$1" readme="$LG_REPO/tweaks/$1/README.md" deps
    echo "$(lg_mf .name "$t")  ($t, v$(lg_mf .version "$t"))"
    echo
    lg_mf .summary "$t" | fold -s -w 100
    echo
    echo "Status:         $(lg_mf .status "$t")"
    echo "Scope:          $(lg_mf .scope "$t")"
    echo "Needs sudo:     $(lg_mf .requires_root "$t")"
    deps=$(lg_mf '.depends[]' "$t" | tr '\n' ' ')
    echo "Depends on:     ${deps:-nothing}"
    echo "Tested on:      SteamOS $(lg_mf '.tested_steamos[]' "$t" | tr '\n' ' ')"
    echo "After install:  $(lg_mf .restart "$t")"
    echo
    # The "What This Tweak Does" section of the README
    awk '/^## What This Tweak Does/{f=1; next} /^## /{f=0} f' "$readme" | sed '/^$/N;/^\n$/D'
    echo "Full guide: tweaks/$t/README.md"
    check_state "$t"
    echo
    echo "On this device: $CHECK_STATE ($CHECK_DETAIL)"
}

cmd_check() {
    require_tweak "$1"
    echo "Checking $1 ..."
    run_script "$1" check.sh
}

cmd_status() {
    local t
    if [ -z "${1:-}" ]; then
        for t in $(tweak_ids); do cmd_status "$t"; echo; done
        return
    fi
    require_tweak "$1"
    t="$1"
    check_state "$t"
    echo "$t: $CHECK_STATE ($CHECK_DETAIL)"
    if lg_is_tracked_tweak "$t"; then
        echo "  mode:         $(lg_state_get mode "$t")"
        echo "  version:      $(lg_state_get version "$t") (repository: $(lg_mf .version "$t"))"
        echo "  installed at: $(lg_state_get installed_at "$t")"
        echo "  state dir:    $LG_STATE/$t"
    fi
    if [ -f "$LG_REPO/tweaks/$t/status.sh" ]; then run_script "$t" status.sh | sed 's/^/  /'; fi
}

cmd_install() {
    require_tweak "$1"
    local t="$1" dep
    lg_step "Installing $(lg_mf .name "$t") ($t)"
    check_state "$t"
    printf '%s\n' "$CHECK_OUTPUT" | grep -v '^RESULT='
    case "$CHECK_STATE" in
        installed)   lg_info "Already installed; re-applying (only changed files are rewritten)." ;;
        not-installed) ;;
        untested)
            [ "$LG_FORCE" = 1 ] || lg_die "This SteamOS version is untested for $t. Re-run with --force to install anyway."
            lg_warn "installing on an untested SteamOS version (--force)" ;;
        external)
            lg_die "An equivalent setup is already present ($CHECK_DETAIL). Nothing was changed.
       Run './legiongo.sh adopt $t' to manage it with this tool, or remove it first." ;;
        not-needed)  lg_die "Not needed on this system: $CHECK_DETAIL" ;;
        partial)
            lg_warn "previous installation is incomplete ($CHECK_DETAIL); re-applying" ;;
        conflict)    lg_die "Conflict: $CHECK_DETAIL. Nothing was changed." ;;
        *)           lg_die "Cannot install: $CHECK_DETAIL" ;;
    esac

    for dep in $(lg_mf '.depends[]' "$t"); do
        if ! dep_satisfied "$dep"; then
            lg_warn "$t needs '$dep' ($(lg_mf .name "$dep")): $(lg_mf .summary "$dep" | cut -c1-160)..."
            lg_confirm "Install the dependency '$dep' first?" || lg_die "Dependency '$dep' is required. Nothing was changed."
            cmd_install "$dep" || lg_die "Dependency '$dep' failed to install. Nothing else was changed."
        fi
    done

    if [ "$(lg_mf .requires_root "$t")" = true ] && [ "$LG_TEST" != 1 ] && [ "$(id -u)" != 0 ]; then
        lg_info "This tweak changes system files and needs administrator rights (sudo)."
        sudo -v || lg_die "sudo is required for $t"
    fi

    if run_script "$t" install.sh; then
        check_state "$t"
        if [ "$CHECK_STATE" = installed ]; then
            lg_ok "$t installed and verified"
        else
            lg_warn "$t installed, but verification reports: $CHECK_STATE ($CHECK_DETAIL)"
        fi
        lg_info "Next: $(lg_mf .restart "$t")"
    else
        lg_error "installation of $t failed; rolling back the partial changes"
        run_script "$t" uninstall.sh --rollback || true
        lg_die "rollback finished; see $LG_STATE/.uninstalled/ for the log"
    fi
}

cmd_uninstall() {
    require_tweak "$1"
    local t="$1" other
    if ! lg_is_tracked_tweak "$t"; then
        check_state "$t"
        if [ "$CHECK_STATE" = external ]; then
            lg_die "$t is present but was not installed by this tool ($CHECK_DETAIL).
       Run './legiongo.sh adopt $t' first, then uninstall; or follow the manual steps in tweaks/$t/README.md."
        fi
        lg_info "$t is not installed."
        return 0
    fi
    for other in $(tweak_ids); do
        [ "$other" = "$t" ] && continue
        if lg_mf '.depends[]' "$other" | grep -qx "$t" && lg_is_tracked_tweak "$other"; then
            lg_warn "'$other' is installed and depends on '$t'"
            lg_confirm "Uninstall '$t' anyway?" || lg_die "cancelled"
        fi
    done
    if [ "$(lg_mf .requires_root "$t")" = true ] && [ "$LG_TEST" != 1 ] && [ "$(id -u)" != 0 ]; then
        sudo -v || lg_die "sudo is required to uninstall $t"
    fi
    lg_step "Uninstalling $t"
    if run_script "$t" uninstall.sh; then
        lg_ok "$t removed"
    else
        lg_warn "$t removed with warnings (files you changed were kept; see above)"
    fi
}

cmd_adopt() {
    require_tweak "$1"
    local t="$1"
    [ -f "$LG_REPO/tweaks/$t/adopt.sh" ] || lg_die "$t has no adoption support"
    if lg_is_tracked_tweak "$t"; then lg_info "$t is already managed ($(lg_state_get mode "$t"))."; return 0; fi
    check_state "$t"
    [ "$CHECK_STATE" = external ] || lg_die "nothing to adopt: check reports '$CHECK_STATE' ($CHECK_DETAIL)"
    lg_step "Adopting the existing $t setup (no files are changed)"
    run_script "$t" adopt.sh || lg_die "adoption failed"
    check_state "$t"
    echo "$t: $CHECK_STATE ($CHECK_DETAIL)"
}

# ---------------------------------------------------------------- argument parsing
ARGS=()
for a in "$@"; do
    case "$a" in
        --yes|-y) LG_ASSUME_YES=1 ;;
        --force)  LG_FORCE=1 ;;
        -h|--help) ARGS+=(help) ;;
        *) ARGS+=("$a") ;;
    esac
done
export LG_ASSUME_YES LG_FORCE
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "${1:-help}" in
    list)      cmd_list ;;
    info)      cmd_info "${2:-}" ;;
    check)     cmd_check "${2:-}" ;;
    status)    cmd_status "${2:-}" ;;
    install)   cmd_install "${2:-}" ;;
    uninstall) cmd_uninstall "${2:-}" ;;
    adopt)     cmd_adopt "${2:-}" ;;
    help)      usage ;;
    *)         usage; exit 2 ;;
esac
