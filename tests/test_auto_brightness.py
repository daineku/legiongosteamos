#!/usr/bin/env python3
"""Unit test of smart-auto-brightness's controller logic with simulated light (no D-Bus, no hardware)."""
import importlib.util, sys, time
spec = importlib.util.spec_from_file_location("ab", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.log = lambda *a: None
clock = [1000.0]; m.time.monotonic = lambda: clock[0]

def make(baseline=3000):
    c = object.__new__(m.Controller)
    c.samples, c.baseline, c.ref_lux, c.ramp, c.pending, c.max = [], baseline, None, None, 0, 10000
    c.brightness = baseline
    c.prop = lambda name: c.brightness
    def start_ramp(a, b): c.brightness = int(b)          # apply instantly in the test
    c.start_ramp = start_ramp
    return c
def feed(c, seconds, lux_fn):
    for i in range(int(seconds * 2)):                     # 2 readings per second
        clock[0] += 0.5; c.add_sample(lux_fn(i))
        if i % 30 == 29: c.evaluate()                    # every 15 s

# 1. steady room: reference set from a full window, no change
c = make(); feed(c, 60, lambda i: 100)
assert c.ref_lux == 100 and c.brightness == 3000, (c.ref_lux, c.brightness)
# 2. hand covers the sensor 5 s out of every 15 s for 2 minutes: no change at all
feed(c, 120, lambda i: 10 if i % 30 < 10 else 100)
assert c.brightness == 3000, c.brightness
# 3. room permanently 10x darker: -10 % (only after persistence), never more
feed(c, 15, lambda i: 10); assert c.brightness == 3000, "must wait for a second agreeing evaluation"
feed(c, 90, lambda i: 10); assert c.brightness == 2700, c.brightness
feed(c, 60, lambda i: 0.5); assert c.brightness == 2700, "clamped at -10 % even in darkness"
# 4. very bright room: +10 % cap
feed(c, 120, lambda i: 5000); assert c.brightness == 3300, c.brightness
# 5. manual change: new baseline, new reference, then +/-10 % around it
c.display = "d"; c.brightness = 6000
c.on_brightness(None, None, None, None, None, type("P", (), {"unpack": lambda self: ("d", 6000, ":1.9", "")})())
feed(c, 60, lambda i: 5000); assert c.baseline == 6000 and c.brightness == 6000, (c.baseline, c.brightness)
feed(c, 120, lambda i: 50); assert c.brightness == 5400, c.brightness
# 6. own changes do not move the baseline
c.on_brightness(None, None, None, None, None, type("P", (), {"unpack": lambda self: ("d", 5400, ":1.9", m.CTX)})())
assert c.baseline == 6000
# 7. floor: never below 5 % from a normal baseline, never above a baseline the user set below 5 %
c2 = make(520); feed(c2, 60, lambda i: 100); feed(c2, 120, lambda i: 1)
assert c2.brightness == 520, c2.brightness   # 520 -> 500 is below the 2 % minimum step: no change
c3 = make(400); feed(c3, 60, lambda i: 100); feed(c3, 120, lambda i: 1)
assert c3.brightness == 400, c3.brightness
print("ok")
