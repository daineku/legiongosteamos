# shellcheck shell=bash
# steam-keyboard: KDE config helpers (sourced). Shared files (kwinrulesrc, kxkbrc) are edited key by key
# with kwriteconfig6, never replaced, and only the entries this tweak added are removed again.

RULE_KEYS="Description title titlematch wmclass wmclassmatch layer layerrule"

_kwin_reconfigure() { qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; }

kde_add_kwin_rule() {   # kde_add_kwin_rule GROUP
    local g="$1" rules f="$HOME/.config/kwinrulesrc"
    if [ -e "$f" ] && [ ! -e "$(lg_sdir)/backups/kwinrulesrc.before" ]; then
        mkdir -p "$(lg_sdir)/backups"; cp -a "$f" "$(lg_sdir)/backups/kwinrulesrc.before"
    fi
    kwriteconfig6 --file kwinrulesrc --group "$g" --key Description "Steam on-screen keyboard above launcher/popups (legiongo-steamos)"
    kwriteconfig6 --file kwinrulesrc --group "$g" --key title "Steam Input On-screen Keyboard"
    kwriteconfig6 --file kwinrulesrc --group "$g" --key titlematch 1
    kwriteconfig6 --file kwinrulesrc --group "$g" --key wmclass steam
    kwriteconfig6 --file kwinrulesrc --group "$g" --key wmclassmatch 1
    kwriteconfig6 --file kwinrulesrc --group "$g" --key layer 8
    kwriteconfig6 --file kwinrulesrc --group "$g" --key layerrule 2
    rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules)
    if ! printf '%s' "$rules" | tr ',' '\n' | grep -qx "$g"; then
        rules="${rules:+$rules,}$g"
    fi
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$rules"
    kwriteconfig6 --file kwinrulesrc --group General --key count "$(printf '%s' "$rules" | tr ',' '\n' | grep -c .)"
    _kwin_reconfigure
    lg_log "kwin rule $g added"
}

kde_remove_kwin_rule() {   # kde_remove_kwin_rule GROUP
    local g="$1" k rules
    for k in $RULE_KEYS; do kwriteconfig6 --file kwinrulesrc --group "$g" --key "$k" --delete; done
    rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules | tr ',' '\n' | grep -vx "$g" | grep . | paste -sd, -)
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$rules"
    kwriteconfig6 --file kwinrulesrc --group General --key count "$(printf '%s' "$rules" | tr ',' '\n' | grep -c .)"
    _kwin_reconfigure
    lg_log "kwin rule $g removed"
}

kde_add_layout() {   # kde_add_layout CODE... (XKB layout codes, optionally "code(variant)"; restored on uninstall)
    local list variants new nvar code lay var added=""
    [ -z "$(lg_state_get layout_after)" ] || { lg_info "layouts were already added by this tweak"; return 0; }
    list=$(kreadconfig6 --file kxkbrc --group Layout --key LayoutList)
    variants=$(kreadconfig6 --file kxkbrc --group Layout --key VariantList)
    new="${list:-us}"; nvar="$variants"
    [ -n "$list" ] || nvar=""
    for code in "$@"; do
        [[ "$code" =~ ^[a-z]{2,3}(\([a-z0-9_]+\))?$ ]] || lg_die "invalid layout '$code' (use XKB codes such as de, fr, ua or us(intl))"
        lay=${code%%(*}; var=""; [ "$lay" != "$code" ] && { var=${code#*(}; var=${var%)}; }
        if paste -d'|' <(printf '%s' "$new" | tr ',' '\n') <(printf '%s' "$nvar" | tr ',' '\n') | grep -qx "$lay|$var"; then
            lg_info "layout $code already configured"; continue
        fi
        new="$new,$lay"; nvar="$nvar,$var"; added="$added $code"
    done
    [ -n "$added" ] || return 0
    lg_state_set layout_before "$list"
    lg_state_set variants_before "$variants"
    lg_state_set use_before "$(kreadconfig6 --file kxkbrc --group Layout --key Use)"
    lg_state_set layout_after "$new"
    kwriteconfig6 --file kxkbrc --group Layout --key Use true
    kwriteconfig6 --file kxkbrc --group Layout --key VariantList "$nvar"
    kwriteconfig6 --notify --file kxkbrc --group Layout --key LayoutList "$new"
    lg_ok "KDE layouts: $new"
}

kde_restore_layout() {
    local after cur
    after=$(lg_state_get layout_after)
    [ -n "$after" ] || return 0
    cur=$(kreadconfig6 --file kxkbrc --group Layout --key LayoutList)
    if [ "$cur" != "$after" ]; then lg_warn "KDE layouts were changed since install ($cur); left as they are"; return 0; fi
    kwriteconfig6 --file kxkbrc --group Layout --key VariantList "$(lg_state_get variants_before)"
    if [ -n "$(lg_state_get use_before)" ]; then kwriteconfig6 --file kxkbrc --group Layout --key Use "$(lg_state_get use_before)"
    else kwriteconfig6 --file kxkbrc --group Layout --key Use --delete; fi
    if [ -n "$(lg_state_get layout_before)" ]; then
        kwriteconfig6 --notify --file kxkbrc --group Layout --key LayoutList "$(lg_state_get layout_before)"
    else
        kwriteconfig6 --notify --file kxkbrc --group Layout --key LayoutList --delete
    fi
    lg_ok "KDE layouts restored"
}
