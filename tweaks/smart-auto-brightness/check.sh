#!/bin/bash
# smart-auto-brightness: requirements (capabilities) and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"
lg_check_platform
lg_req "ambient light sensor via iio-sensor-proxy" sh -c 'busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAmbientLight 2>/dev/null | grep -q true'
lg_req "Plasma brightness API (org.kde.ScreenBrightness)" sh -c 'busctl --user get-property org.kde.ScreenBrightness /org/kde/ScreenBrightness org.kde.ScreenBrightness DisplaysDBusNames 2>/dev/null | grep -q display'
lg_req "KWin automatic-brightness control (kscreen-doctor, jq)" sh -c 'command -v kscreen-doctor >/dev/null && command -v jq >/dev/null && kscreen-doctor -o 2>/dev/null | sed "s/\x1b\[[0-9;]*m//g" | grep -q "Automatic brightness: supported"'
lg_req "python3 with GObject introspection (Gio)" lg_python_gi Gio 2.0
lg_check_result 0
