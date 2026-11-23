#!/bin/bash
# decky-loader: the service runs steadily and its local server answers (127.0.0.1:1337).
. "$LG_REPO/lib/common.sh"
lg_unit_stable root plugin_loader.service || { lg_error "plugin_loader.service is not running steadily"; exit 1; }
if lg_wait_for "$(lg_verify_timeout 15)" sh -c 'ss -ltn 2>/dev/null | grep -q "127.0.0.1:1337"'; then lg_ok "Decky Loader is serving"; exit 0; fi
lg_error "Decky Loader runs but its server is not listening"; exit 1
