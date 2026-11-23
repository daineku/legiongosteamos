# shellcheck shell=bash
# Install-state tracking, backups and safe file operations. Sourced by lib/common.sh.
#
# Every tweak keeps its state in $LG_STATE/<tweak>/:
#   state        key=value lines (mode=installed|adopted, version, installed_at, ...)
#   manifest.tsv one line per change, in the order it was made:
#                kind <TAB> path <TAB> owner <TAB> mode <TAB> sha256 <TAB> backup
#                kind:  created   file created by the tweak (removed on uninstall if unchanged)
#                       replaced  file that existed before; the original is in backup (restored on uninstall)
#                       adopted   pre-existing equivalent file recorded by "adopt" (removed on uninstall if unchanged)
#                       dir       directory created by the tweak (removed on uninstall if empty)
#                       unit      systemd unit enabled by the tweak (path = unit name, owner = user|root)
#                owner: user | root  (root files are written through sudo)
#   backups/     original copies of replaced files
#   log          what was done, with timestamps
# Uninstall walks the manifest backwards. Files the user changed after installation are kept
# (with a warning) instead of being deleted or overwritten.

lg_sdir() { printf '%s/%s' "$LG_STATE" "$LG_TWEAK"; }
lg_manifest() { printf '%s/manifest.tsv' "$(lg_sdir)"; }

# ---------------------------------------------------------------- key=value state
lg_state_get() {   # lg_state_get KEY [TWEAK]
    local f="$LG_STATE/${2:-$LG_TWEAK}/state"
    [ -r "$f" ] || return 0
    sed -n "s/^$1=//p" "$f" | tail -1
}
lg_state_set() {   # lg_state_set KEY VALUE
    local d f
    d=$(lg_sdir); f="$d/state"
    mkdir -p "$d"
    touch "$f"
    grep -v "^$1=" "$f" > "$f.tmp" || true
    printf '%s=%s\n' "$1" "$2" >> "$f.tmp"
    mv -f "$f.tmp" "$f"
}
lg_is_tracked_tweak() { [ -s "$LG_STATE/${1:-$LG_TWEAK}/state" ]; }

# ---------------------------------------------------------------- privileged helper
lg_root() {
    if [ "${LG_TEST:-0}" = 1 ] || [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}

lg_sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

# ---------------------------------------------------------------- manifest
lg_manifest_add() {   # kind path owner mode sha backup
    mkdir -p "$(lg_sdir)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$(lg_manifest)"
}
lg_manifest_lookup() {   # lg_manifest_lookup PATH -> prints the line (file kinds only)
    local m; m=$(lg_manifest)
    [ -r "$m" ] || return 1
    awk -F'\t' -v p="$1" '$2 == p && ($1 == "created" || $1 == "replaced" || $1 == "adopted")' "$m" | tail -1 | grep .
}
lg_manifest_set_sha() {   # lg_manifest_set_sha PATH SHA
    local m; m=$(lg_manifest)
    awk -F'\t' -v OFS='\t' -v p="$1" -v s="$2" '$2 == p && $1 != "dir" && $1 != "unit" {$5 = s} {print}' "$m" > "$m.tmp"
    mv -f "$m.tmp" "$m"
}
lg_manifest_has() {   # lg_manifest_has KIND PATH
    local m; m=$(lg_manifest)
    [ -r "$m" ] && awk -F'\t' -v k="$1" -v p="$2" '$1 == k && $2 == p {f = 1} END {exit !f}' "$m"
}

# ---------------------------------------------------------------- directories
lg_mkdir() {   # lg_mkdir DIR user|root   (records each directory it creates)
    local dir="$1" owner="$2" missing=() d
    d="$dir"
    while [ ! -d "$d" ]; do missing=("$d" "${missing[@]}"); d=$(dirname "$d"); done
    for d in "${missing[@]}"; do
        if [ "$owner" = root ]; then lg_root mkdir -m 755 "$d"; else mkdir -m 755 "$d"; fi
        lg_manifest_add dir "$d" "$owner" 755 "" ""
    done
}

# ---------------------------------------------------------------- files
_lg_write() {   # _lg_write SRC DEST MODE OWNER   (atomic: temp file in the same directory, then rename)
    local tmp="$2.lgtmp.$$"
    if [ "$4" = root ]; then
        if [ "${LG_TEST:-0}" = 1 ]; then install -m "$3" "$1" "$tmp"
        else lg_root install -m "$3" -o root -g root "$1" "$tmp"; fi
        lg_root mv -f "$tmp" "$2"
    else
        install -m "$3" "$1" "$tmp"
        mv -f "$tmp" "$2"
    fi
}

lg_put_file() {   # lg_put_file SRC DEST MODE user|root
    local src="$1" dest="$2" mode="$3" owner="$4" new cur rec bk
    new=$(lg_sha "$src")
    lg_mkdir "$(dirname "$dest")" "$owner"
    if [ -e "$dest" ]; then
        cur=$(lg_sha "$dest")
        if rec=$(lg_manifest_lookup "$dest"); then
            # already ours (re-install or upgrade)
            if [ "$cur" = "$new" ]; then lg_log "unchanged $dest"; return 0; fi
            if [ "$cur" != "$(printf '%s' "$rec" | cut -f5)" ]; then
                bk="$(lg_sdir)/backups/user-modified.$(date +%Y%m%d-%H%M%S).$(basename "$dest")"
                mkdir -p "$(dirname "$bk")"; cat "$dest" > "$bk"
                lg_warn "$dest was changed after installation; your version is saved as $bk"
            fi
            _lg_write "$src" "$dest" "$mode" "$owner"
            lg_manifest_set_sha "$dest" "$new"
            lg_log "updated $dest"
            return 0
        fi
        # a pre-existing file that is not ours: back it up, remember its mode/owner
        local omode
        omode=$(stat -c %a "$dest")
        bk="$(lg_sdir)/backups/$(printf '%s' "$dest" | sed 's|^/||; s|/|__|g')"
        mkdir -p "$(dirname "$bk")"
        cat "$dest" > "$bk"
        _lg_write "$src" "$dest" "$mode" "$owner"
        lg_manifest_add replaced "$dest" "$owner" "$omode" "$new" "$bk"
        lg_log "replaced $dest (backup $bk)"
    else
        _lg_write "$src" "$dest" "$mode" "$owner"
        lg_manifest_add created "$dest" "$owner" "$mode" "$new" ""
        lg_log "created $dest"
    fi
}

lg_put_content() {   # lg_put_content DEST MODE user|root  (content on stdin)
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/lg.XXXXXX")
    cat > "$tmp"
    lg_put_file "$tmp" "$1" "$2" "$3"
    rm -f "$tmp"
}

lg_adopt_file() {   # lg_adopt_file PATH user|root
    [ -e "$1" ] || return 0
    lg_manifest_has adopted "$1" && return 0
    lg_manifest_add adopted "$1" "$2" "$(stat -c %a "$1")" "$(lg_sha "$1")" ""
    lg_log "adopted $1"
}

# ---------------------------------------------------------------- systemd units
lg_systemctl() {   # lg_systemctl user|root ARGS...
    local scope="$1"; shift
    if [ "$scope" = root ]; then lg_root systemctl "$@"; else systemctl --user "$@"; fi
}
lg_unit_enable() {   # lg_unit_enable user|root UNIT [--now]
    lg_systemctl "$1" daemon-reload
    lg_systemctl "$1" enable ${3:+"$3"} "$2"
    lg_manifest_has unit "$2" || lg_manifest_add unit "$2" "$1" "" "" ""
    lg_log "enabled $1 unit $2"
}
lg_adopt_unit() {   # lg_adopt_unit user|root UNIT
    lg_manifest_has unit "$2" || lg_manifest_add unit "$2" "$1" "" "" ""
    lg_log "adopted $1 unit $2"
}

# ---------------------------------------------------------------- rollback
# Undo everything in the manifest, newest first. Never deletes files changed after installation.
lg_rollback() {
    local m kept=0 kind path owner mode sha bk cur
    m=$(lg_manifest)
    [ -r "$m" ] || return 0
    while IFS=$'\t' read -r kind path owner mode sha bk; do
        case "$kind" in
            unit)
                lg_systemctl "$owner" disable --now "$path" >/dev/null 2>&1 || true
                lg_log "disabled $owner unit $path"
                ;;
            created|adopted)
                [ -e "$path" ] || continue
                cur=$(lg_sha "$path")
                if [ "$cur" = "$sha" ]; then
                    if [ "$owner" = root ]; then lg_root rm -f "$path"; else rm -f "$path"; fi
                    lg_log "removed $path"
                else
                    lg_warn "kept $path: it was changed after installation"
                    kept=$((kept + 1))
                fi
                ;;
            replaced)
                cur=$(lg_sha "$path")
                if [ ! -e "$path" ] || [ "$cur" = "$sha" ]; then
                    if [ -r "$bk" ]; then
                        lg_mkdir_quiet "$(dirname "$path")" "$owner"
                        _lg_write "$bk" "$path" "${mode:-644}" "$owner"
                        lg_log "restored $path from $bk"
                    fi
                else
                    lg_warn "kept $path: it was changed after installation (original: $bk)"
                    kept=$((kept + 1))
                fi
                ;;
            dir)
                if [ -d "$path" ] && [ -z "$(ls -A "$path" 2>/dev/null)" ]; then
                    if [ "$owner" = root ]; then lg_root rmdir "$path"; else rmdir "$path"; fi
                fi
                ;;
        esac
    done < <(tac "$m")
    [ "$(id -u)" = 0 ] || systemctl --user daemon-reload >/dev/null 2>&1 || true
    return "$kept"
}
lg_mkdir_quiet() { if [ "$2" = root ]; then lg_root mkdir -p "$1"; else mkdir -p "$1"; fi; }

# Move the state directory aside after a successful uninstall (keeps backups and logs for reference).
lg_state_archive() {
    local d; d=$(lg_sdir)
    [ -d "$d" ] || return 0
    mkdir -p "$LG_STATE/.uninstalled"
    mv "$d" "$LG_STATE/.uninstalled/$LG_TWEAK.$(date +%Y%m%d-%H%M%S)"
}

# Every file recorded by the manifest still exists with the recorded content?
lg_verify_manifest() {
    local m kind path owner mode sha bk bad=0
    m=$(lg_manifest)
    [ -r "$m" ] || return 1
    while IFS=$'\t' read -r kind path owner mode sha bk; do
        case "$kind" in
            created|replaced|adopted)
                if [ ! -e "$path" ]; then lg_warn "missing: $path"; bad=1
                elif [ "$(lg_sha "$path")" != "$sha" ]; then lg_warn "changed since install: $path"; bad=1; fi ;;
        esac
    done < "$m"
    return "$bad"
}

# ---------------------------------------------------------------- shared resources (reference counted)
# A file that several tweaks need (e.g. Steam's debugger flag, used by steam-keyboard and decky-loader).
# $LG_STATE/.shared/<name> lists the tweaks holding it; "preexisting" marks a file that existed before any
# tweak created it. The file is deleted only when the last holder releases it and no tweak found it pre-existing.
lg_shared_file() { printf '%s/.shared/%s' "$LG_STATE" "$1"; }
lg_shared_acquire() {   # lg_shared_acquire NAME PATH   (creates an empty PATH if missing)
    local f; f=$(lg_shared_file "$1")
    mkdir -p "$(dirname "$f")"; touch "$f"
    if [ ! -e "$2" ]; then
        mkdir -p "$(dirname "$2")"; : > "$2"
        lg_log "created shared $1 ($2)"
    elif [ ! -s "$f" ]; then
        echo preexisting >> "$f"
    fi
    grep -qx "$LG_TWEAK" "$f" || echo "$LG_TWEAK" >> "$f"
    lg_state_set "shared_$1" "$2"
}
lg_shared_release() {   # lg_shared_release NAME [KEEP_IF_EXISTS]   (keep the file while KEEP_IF_EXISTS exists)
    local f path; f=$(lg_shared_file "$1"); path=$(lg_state_get "shared_$1")
    [ -n "$path" ] && [ -e "$f" ] || return 0
    grep -vx "$LG_TWEAK" "$f" > "$f.tmp" || true; mv -f "$f.tmp" "$f"
    if grep -qvx preexisting "$f"; then
        lg_info "kept $path (still used by: $(grep -vx preexisting "$f" | paste -sd, -))"
    elif grep -qx preexisting "$f"; then
        lg_info "kept $path (it existed before installation)"
        rm -f "$f"
    elif [ -n "${2:-}" ] && [ -e "$2" ]; then
        lg_info "kept $path (needed by $2)"
        rm -f "$f"
    else
        rm -f "$path" "$f"; lg_log "removed shared $1 ($path)"
    fi
}
