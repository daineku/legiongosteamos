# shellcheck shell=bash
# Creates stub commands in $1 that emulate systemctl, kwriteconfig6, ... inside the sandbox.
# Calls are logged to $SANDBOX/calls.log.
make_stubs() {
    local d="$1"; mkdir -p "$d"
    cat > "$d/systemctl" <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$SANDBOX/calls.log"
case " $* " in *" is-active "*) [ -e "$SANDBOX/fail-active" ] && exit 3; echo active ;; esac
exit 0
EOF
    # journalctl: canned "healthy" log lines for verify.sh; $SANDBOX/journal-fail makes them report failures
    cat > "$d/journalctl" <<'EOF'
#!/bin/bash
[ -e "$SANDBOX/journal-fail" ] && { echo "legion-tp-handover: ENABLE native touchpad: [] -> [] FAILED: denied"; exit 0; }
printf '%s\n' "lgk: lgk: installed v41" "legion-tp-handover: watching Steam controller node /dev/hidraw7" \
    "legion-power: applied desktop policy (start): battery, balanced, EPP balance_performance"
EOF
    cat > "$d/ss" <<'EOF'
#!/bin/bash
[ -e "$SANDBOX/ss-fail" ] || echo "LISTEN 0 128 127.0.0.1:1337 0.0.0.0:*"
EOF
    # kwriteconfig6/kreadconfig6: flat key store "file|group|group|key=value"
    cat > "$d/kwriteconfig6" <<'EOF'
#!/bin/bash
echo "kwriteconfig6 $*" >> "$SANDBOX/calls.log"
file=""; groups=""; key=""; del=0; val=""
while [ $# -gt 0 ]; do
  case "$1" in --file) file=$2; shift ;; --group) groups="$groups|$2"; shift ;; --key) key=$2; shift ;;
    --delete) del=1 ;; --notify) ;; *) val=$1 ;; esac; shift
done
k="$file$groups|$key"; db="$SANDBOX/kconfig.db"; touch "$db"
grep -vF "$k=" "$db" > "$db.tmp" || true; mv "$db.tmp" "$db"
[ "$del" = 1 ] || printf '%s=%s\n' "$k" "$val" >> "$db"
EOF
    cat > "$d/kreadconfig6" <<'EOF'
#!/bin/bash
file=""; groups=""; key=""
while [ $# -gt 0 ]; do
  case "$1" in --file) file=$2; shift ;; --group) groups="$groups|$2"; shift ;; --key) key=$2; shift ;; esac; shift
done
k="$file$groups|$key"; db="$SANDBOX/kconfig.db"; touch "$db"
grep -F "$k=" "$db" | tail -1 | cut -d= -f2-
EOF
    printf '#!/bin/bash\necho "qdbus6 $*" >> "$SANDBOX/calls.log"\n' > "$d/qdbus6"
    cat > "$d/busctl" <<'EOF'
#!/bin/bash
echo "busctl $*" >> "$SANDBOX/calls.log"
case " $* " in *" tree "*) [ -e "$SANDBOX/busctl-fail" ] || echo "/org/shadowblip/InputPlumber/CompositeDevice0" ;; esac
EOF
    cat > "$d/pacman" <<'EOF'
#!/bin/bash
[ "$1" = -Q ] && [ "$2" = inputplumber ] && echo "inputplumber ${STUB_IP_VERSION:-0.78.0}-1"
exit 0
EOF
    cat > "$d/sudo" <<'EOF'
#!/bin/bash
echo "UNEXPECTED sudo $*" >> "$SANDBOX/calls.log"; exit 1
EOF
    cat > "$d/pactl" <<'EOF'
#!/bin/bash
echo "pactl $*" >> "$SANDBOX/calls.log"; st="$SANDBOX/pactl.state"; touch "$st"
case "$1" in
  list) if [ "$2" = short ]; then printf '1\talsa_loopback_device.x\tPipeWire\n'
           [ -e "$HOME/.config/pipewire/filter-chain.conf.d/60-legiongo-mic-enhance.conf" ] && printf '2\tlegiongo_mic_enhanced\tPipeWire\n'
           printf '3\tdefault_mic\tPipeWire\n'
        else printf 'Card #1\n\tName: alsa_card.pci-0000_c2_00.6\n\tActive Profile: %s\n' "$(sed -n 's/^profile=//p' "$st" | tail -1 || true)"; fi ;;
  get-default-source) v=$(sed -n 's/^default=//p' "$st" | tail -1); echo "${v:-default_mic}" ;;
  set-default-source) echo "default=$2" >> "$st" ;;
  set-card-profile) echo "profile=$3" >> "$st" ;;
esac
EOF
    cat > "$d/id" <<'EOF'
#!/bin/bash
# the sandbox user counts as a member of "wheel" (InputPlumber's polkit group on SteamOS)
if [ "$*" = "-nG" ]; then echo "$(/usr/bin/id -nG) wheel"; else exec /usr/bin/id "$@"; fi
EOF
    cat > "$d/pw-dump" <<'EOF'
#!/bin/bash
echo '[{"type":"PipeWire:Interface:Node","info":{"props":{"node.name":"alsa_input.pci-0000_c2_00.6.analog-stereo"}}}]'
EOF
    chmod +x "$d"/*
}

# Mock system root: Legion Go DMI, SteamOS os-release, sysfs and unit files.
make_root() {
    local r="$1" ver="${2:-3.9.5}" product="${3:-83E1}"
    mkdir -p "$r/sys/class/dmi/id" "$r/etc" "$r/usr/lib/systemd/system" "$r/usr/lib/systemd/user" "$r/usr/lib/ladspa" \
             "$r/sys/class/platform-profile/platform-profile-0" "$r/sys/devices/system/cpu/cpu0/cpufreq" "$r/dev"
    echo "$product" > "$r/sys/class/dmi/id/product_name"
    [ "$product" = 83E1 ] && echo "Legion Go 8APU1" > "$r/sys/class/dmi/id/product_version" || echo "Other" > "$r/sys/class/dmi/id/product_version"
    printf 'NAME="SteamOS"\nPRETTY_NAME="SteamOS"\nID=steamos\nVERSION_ID=%s\n' "$ver" > "$r/etc/os-release"
    mkdir -p "$r/usr/share/inputplumber/devices"
    # stock 0.78-style Legion profile: no native touchpad interface (interface_num: 1) entries
    printf 'name: Lenovo Legion Go\nsource_devices:\n  - group: gamepad\n    hidraw:\n      interface_num: 2\n' > "$r/usr/share/inputplumber/devices/50-legion_go.yaml"
    touch "$r/usr/lib/systemd/system/inputplumber.service" "$r/usr/lib/systemd/system/upower.service" \
          "$r/usr/lib/systemd/user/filter-chain.service" "$r/usr/lib/ladspa/caps.so" "$r/dev/uinput"
    echo lenovo-wmi-gamezone > "$r/sys/class/platform-profile/platform-profile-0/name"
    echo custom > "$r/sys/class/platform-profile/platform-profile-0/profile"
    echo balance_power > "$r/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
}
