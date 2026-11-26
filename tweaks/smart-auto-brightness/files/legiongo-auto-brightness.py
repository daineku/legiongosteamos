#!/usr/bin/env python3
"""legiongo-auto-brightness: gentle ambient-light brightness for KDE Plasma (Desktop Mode).

Replaces KWin's built-in automatic brightness (which maps lux to an absolute brightness and reacts after
2 s, so a hand over the sensor dims the screen) with ONE controller that:
  - keeps the brightness you set as the baseline; every brightness change not made by this controller
    (slider, keys, Plasma) becomes the new baseline;
  - stays within +/-RANGE (10 %) of that baseline: 10x darker -> -10 %, 10x brighter -> +10 % (capped at max);
  - judges the light by the 90th percentile of the last WINDOW_S seconds (a hand can only darken the
    sensor, so shadows are ignored unless they cover almost the whole window), re-evaluated every EVAL_S
    seconds, and only acts when two evaluations in a row agree;
  - treats light below LUX_FLOOR as LUX_FLOOR, so tiny readings in a dark room cannot swing it;
  - only changes when the difference is >= MIN_STEP and ramps softly over RAMP_S seconds;
  - never goes below FLOOR.
Event-driven: sensor readings arrive as D-Bus signals from iio-sensor-proxy; one timer per EVAL_S.
Brightness is set through Plasma's own org.kde.ScreenBrightness API (the same path as the slider).
"""
import math, signal, time
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

CTX = "legiongo-auto-brightness"
RANGE = 0.10          # max deviation from the baseline (fraction of the baseline)
EVAL_S = 15           # evaluation interval
WINDOW_S = 30         # light is judged by the median over this window
MIN_STEP = 0.02       # minimum change worth applying (fraction of max brightness)
FLOOR = 0.05          # never below 5 % of max
RAMP_S, RAMP_STEPS = 2.0, 10
PERCENTILE = 0.9      # shadows only lower readings: judge the light by a high percentile
LUX_FLOOR = 5.0       # dark-room readings below this count as this
SP = ("net.hadess.SensorProxy", "/net/hadess/SensorProxy", "net.hadess.SensorProxy")
SB = "org.kde.ScreenBrightness"


def log(*a):
    print("auto-brightness:", *a, flush=True)


class Controller:
    def __init__(self):
        self.sysbus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.samples = []            # (monotonic time, lux)
        self.baseline = None         # brightness the user set (absolute units)
        self.ref_lux = None          # median lux when the baseline was set
        self.ramp = None
        self.pending = 0             # direction (+1/-1) proposed by the previous evaluation
        self.started = time.monotonic()
        self.display = self.find_display()
        self.max = self.prop("MaxBrightness")
        self.baseline = self.prop("Brightness")
        log(f"display {self.display}, baseline {self.baseline}/{self.max}")
        self.sysbus.signal_subscribe(SP[0], "org.freedesktop.DBus.Properties", "PropertiesChanged", SP[1], None,
                                     Gio.DBusSignalFlags.NONE, self.on_sensor)
        self.sysbus.call_sync(SP[0], SP[1], SP[2], "ClaimLight", None, None, Gio.DBusCallFlags.NONE, 3000, None)
        self.add_sample(self.sensor_prop("LightLevel"))
        self.bus.signal_subscribe(SB, SB, "BrightnessChanged", "/org/kde/ScreenBrightness", None,
                                  Gio.DBusSignalFlags.NONE, self.on_brightness)
        self.sysbus.signal_subscribe("org.freedesktop.login1", "org.freedesktop.login1.Manager", "PrepareForSleep",
                                     "/org/freedesktop/login1", None, Gio.DBusSignalFlags.NONE, self.on_sleep)
        GLib.timeout_add_seconds(EVAL_S, self.evaluate)

    # ---- D-Bus helpers
    def find_display(self):
        names = self.bus.call_sync(SB, "/org/kde/ScreenBrightness", "org.freedesktop.DBus.Properties", "Get",
                                   GLib.Variant("(ss)", (SB, "DisplaysDBusNames")), None,
                                   Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]
        for n in names:
            if self.bus.call_sync(SB, f"/org/kde/ScreenBrightness/{n}", "org.freedesktop.DBus.Properties", "Get",
                                  GLib.Variant("(ss)", (SB + ".Display", "IsInternal")), None,
                                  Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]:
                return n
        raise RuntimeError("no internal display in org.kde.ScreenBrightness")

    def prop(self, name):
        return self.bus.call_sync(SB, f"/org/kde/ScreenBrightness/{self.display}", "org.freedesktop.DBus.Properties",
                                  "Get", GLib.Variant("(ss)", (SB + ".Display", name)), None,
                                  Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]

    def sensor_prop(self, name):
        return self.sysbus.call_sync(SP[0], SP[1], "org.freedesktop.DBus.Properties", "Get",
                                     GLib.Variant("(ss)", (SP[2], name)), None,
                                     Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]

    def set_brightness(self, value):
        self.bus.call(SB, f"/org/kde/ScreenBrightness/{self.display}", SB + ".Display", "SetBrightnessWithContext",
                      GLib.Variant("(ius)", (int(value), 1, CTX)), None, Gio.DBusCallFlags.NONE, 3000, None, None)

    # ---- inputs
    def add_sample(self, lux):
        now = time.monotonic()
        self.samples.append((now, float(lux)))
        self.samples = [s for s in self.samples if now - s[0] <= WINDOW_S]

    def on_sensor(self, conn, sender, path, iface, sig, params):
        changed = params.unpack()[1]
        if "LightLevel" in changed:
            self.add_sample(changed["LightLevel"])

    def on_brightness(self, conn, sender, path, iface, sig, params):
        display, value, client, context = params.unpack()
        if display != self.display or context == CTX:
            return
        # a manual change (slider, keys, Plasma): new baseline at the current light
        self.cancel_ramp()
        self.baseline = value
        self.ref_lux = self.light()             # None until a full window exists; set at the next evaluation
        self.pending = 0
        log(f"manual change -> baseline {value}/{self.max}" + (f" at {self.ref_lux:.0f} lux" if self.ref_lux else ""))

    def on_sleep(self, conn, sender, path, iface, sig, params):
        if not params.unpack()[0]:          # resumed: old readings are stale
            self.samples = []
            self.pending = 0
            GLib.timeout_add_seconds(3, lambda: (self.add_sample(self.sensor_prop("LightLevel")), False)[1])

    # ---- control
    def light(self):
        """High percentile of the last WINDOW_S seconds (needs a full window of readings)."""
        now = time.monotonic()
        recent = sorted(l for t, l in self.samples if now - t <= WINDOW_S)
        if not recent or now - self.samples[0][0] < WINDOW_S * 0.8:
            return None
        return max(recent[min(len(recent) - 1, int(PERCENTILE * len(recent)))], LUX_FLOOR)

    def evaluate(self):
        lux = self.light()
        if lux is None or self.baseline is None:
            return True
        if self.ref_lux is None:                     # reference light: first full window after a baseline
            self.ref_lux = lux
            log(f"reference light {lux:.0f} lux for baseline {self.baseline}")
            return True
        med = lux
        ratio = max(-1.0, min(1.0, math.log10(lux / self.ref_lux)))
        target = self.baseline * (1 + RANGE * ratio)
        # never below 5 % -- unless you yourself chose less (then never below your own choice)
        target = max(target, self.baseline * (1 - RANGE), min(FLOOR * self.max, self.baseline))
        target = min(target, self.baseline * (1 + RANGE), self.max)
        current = self.prop("Brightness")
        direction = 0 if abs(target - current) < MIN_STEP * self.max else (1 if target > current else -1)
        if direction and direction == self.pending and self.ramp is None:
            log(f"light {med:.0f} lux (ref {self.ref_lux:.0f}): {current} -> {int(target)}")
            self.start_ramp(current, target)
            self.pending = 0
        else:
            self.pending = direction
        return True

    def start_ramp(self, start, end):
        steps = [start + (end - start) * (i + 1) / RAMP_STEPS for i in range(RAMP_STEPS)]
        def step():
            if not steps:
                self.ramp = None
                return False
            self.set_brightness(steps.pop(0))
            return True
        self.ramp = GLib.timeout_add(int(RAMP_S * 1000 / RAMP_STEPS), step)

    def cancel_ramp(self):
        if self.ramp is not None:
            GLib.source_remove(self.ramp)
            self.ramp = None

    def shutdown(self):
        self.cancel_ramp()
        try:
            self.sysbus.call_sync(SP[0], SP[1], SP[2], "ReleaseLight", None, None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass


def main():
    c = Controller()
    loop = GLib.MainLoop()
    for s in (signal.SIGTERM, signal.SIGINT):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, s, loop.quit)
    try:
        loop.run()
    finally:
        c.shutdown()


if __name__ == "__main__":
    main()
