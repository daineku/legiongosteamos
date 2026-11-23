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
  update <tweak>          Update one installed tweak to this version (other tweaks are not touched)
  doctor                  System and compatibility report (no personal data; safe to share)
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
check_state() {   # check_state TWEAK
    local out
    out=$(LG_AS_DEPENDENCY="${LG_AS_DEPENDENCY:-0}" run_script "$1" check.sh 2>&1)
    CHECK_OUTPUT="$out"
    CHECK_LINE=$(printf '%s\n' "$out" | sed -n 's/^RESULT=//p' | tail -1)
    CHECK_STATE=${CHECK_LINE%% *}
    CHECK_DETAIL=${CHECK_LINE#* }
    [ -n "$CHECK_STATE" ] || { CHECK_STATE=error; CHECK_DETAIL="check.sh produced no result"; }
}

dep_satisfied() {   # installed by us, adopted, present externally, or already provided by stock SteamOS
    LG_AS_DEPENDENCY=1 check_state "$1"
    case "$CHECK_STATE" in installed|external|upstream-equivalent) return 0 ;; esac
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
    if [ "$CHECK_STATE" = installed ] && [ -f "$LG_REPO/tweaks/$t/verify.sh" ]; then
        local vr; LG_VERIFY_QUICK=1 run_script "$t" verify.sh >/dev/null 2>&1; vr=$?
        echo "  working:      $(case $vr in 0) echo yes ;; 2) echo "not checkable right now (e.g. outside Desktop Mode)" ;; *) echo "NO — run: ./legiongo.sh check $t" ;; esac)"
    fi
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
        upstream-equivalent)
            [ "$LG_FORCE" = 1 ] || lg_die "Not needed here: $CHECK_DETAIL
       The tweak stays available; re-run with --force to install it anyway."
            lg_warn "installing although SteamOS already provides this (--force)" ;;
        partial)
            lg_warn "previous installation is incomplete ($CHECK_DETAIL); re-applying" ;;
        conflict)    lg_die "Conflict: $CHECK_DETAIL. Nothing was changed." ;;
        *)           lg_die "Cannot install: $CHECK_DETAIL" ;;
    esac

    local installed_deps=()
    for dep in $(lg_mf '.depends[]' "$t"); do
        if ! dep_satisfied "$dep"; then
            lg_warn "$t needs '$dep' ($(lg_mf .name "$dep")): $(lg_mf .summary "$dep" | cut -c1-160)..."
            lg_confirm "Install the dependency '$dep' first?" || lg_die "Dependency '$dep' is required. Nothing was changed."
            ( cmd_install "$dep" ) || { rollback_deps "${installed_deps[@]+"${installed_deps[@]}"}"; lg_die "Dependency '$dep' failed to install; changes of this transaction were rolled back."; }
            installed_deps+=("$dep")
        fi
    done

    if [ "$(lg_mf .requires_root "$t")" = true ] && [ "$LG_TEST" != 1 ] && [ "$(id -u)" != 0 ]; then
        lg_info "This tweak changes system files and needs administrator rights (sudo)."
        sudo -v || lg_die "sudo is required for $t"
    fi

    local why="" vrc=0
    if ! run_script "$t" install.sh; then
        why="an installation step failed"
    else
        # Verification is authoritative: recorded files intact (check.sh) AND the tweak actually works (verify.sh).
        check_state "$t"
        if [ "$CHECK_STATE" != installed ]; then
            why="post-install check reports '$CHECK_STATE' ($CHECK_DETAIL)"
        elif [ -f "$LG_REPO/tweaks/$t/verify.sh" ]; then
            lg_step "Verifying that $t works"
            run_script "$t" verify.sh; vrc=$?
            case "$vrc" in
                0) ;;
                2) lg_warn "functional verification deferred (see above); it runs automatically when the condition is met" ;;
                *) why="functional verification failed (see above)" ;;
            esac
        fi
    fi
    if [ -n "$why" ]; then
        lg_error "installation of $t failed: $why"
        lg_error "rolling back the changes made by this installation (your own files are kept)"
        run_script "$t" uninstall.sh --rollback || true
        rollback_deps "${installed_deps[@]+"${installed_deps[@]}"}"
        lg_die "rollback finished; nothing of $t remains active. Log: $LG_STATE/.uninstalled/"
    fi
    lg_ok "$t installed and verified"
    lg_info "Next: $(lg_mf .restart "$t")"
}

# Undo dependencies that were installed earlier in the same (failed) transaction, newest first.
rollback_deps() {
    local i
    for (( i = $# ; i > 0 ; i-- )); do
        lg_warn "rolling back dependency '${!i}' installed in this transaction"
        run_script "${!i}" uninstall.sh --rollback || true
    done
}

cmd_update() {
    require_tweak "$1"
    local t="$1" have want
    lg_is_tracked_tweak "$t" || lg_die "$t is not installed (install it with: ./legiongo.sh install $t)"
    if [ "$(lg_state_get mode "$t")" = adopted ]; then
        lg_die "$t is an adopted manual setup; it cannot be updated in place.
       To switch to the maintained version: ./legiongo.sh uninstall $t && ./legiongo.sh install $t"
    fi
    have=$(lg_state_get version "$t"); want=$(lg_mf .version "$t")
    if [ "$have" = "$want" ]; then
        check_state "$t"
        if [ "$CHECK_STATE" = installed ]; then lg_ok "$t is up to date (v$want)"; return 0; fi
        lg_info "$t v$want reports '$CHECK_STATE' ($CHECK_DETAIL); repairing"
    else
        lg_step "Updating $t: v$have -> v$want"
    fi
    cmd_install "$t"
}

cmd_doctor() {
    # shellcheck source=lib/doctor.sh
    . "$LG_REPO/lib/doctor.sh"
    lg_doctor
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
            [ "$LG_FORCE" = 1 ] || lg_die "'$other' is installed and depends on '$t'. Uninstall '$other' first, or use --force."
            lg_warn "'$other' depends on '$t'; uninstalling anyway (--force)"
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
    update)    cmd_update "${2:-}" ;;
    doctor)    cmd_doctor ;;
    help)      usage ;;
    *)         usage; exit 2 ;;
esac
