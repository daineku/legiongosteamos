#!/bin/bash
# decky-power-plugins: Decky runs and both plugin folders are complete (plugin.json + main.py).
. "$LG_REPO/lib/common.sh"
lg_unit_stable root plugin_loader.service || { lg_error "Decky Loader is not running"; exit 1; }
for p in SimpleDeckyTDP LegionGoRemapper; do
    for f in plugin.json main.py; do [ -r "$HOME/homebrew/plugins/$p/$f" ] || { lg_error "$p is incomplete ($f missing)"; exit 1; }; done
done
lg_ok "plugins installed; open Quick Access > Decky in Gaming Mode to use them"; exit 0
