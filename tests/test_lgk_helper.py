#!/usr/bin/env python3
"""Unit test for the Multilingual Input Support logic in lgk-helper.py (no D-Bus, no Steam)."""
import importlib.util, json, os, sys, tempfile

os.environ["XDG_RUNTIME_DIR"] = tempfile.mkdtemp()
spec = importlib.util.spec_from_file_location("lgk_helper", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
H = m.Helper

kde = [("us", ""), ("ru", ""), ("de", ""), ("us", "intl")]
assert H.match_layout(kde, "ru") == 1
assert H.match_layout(kde, "us") == 0                 # base layout, not the intl variant
assert H.match_layout(kde, "us", "intl") == 3
assert H.match_layout(kde, "fr") is None
assert H.match_layout(None, "us") is None

class Fake:                                            # just enough of Helper for report_languages()
    kde_layouts = lambda self: kde
    match_layout = staticmethod(H.match_layout)
logged = []
m.log = lambda *a: logged.append(" ".join(map(str, a)))
H.report_languages(Fake(), [
    {"steam": "russian", "kind": "xkb", "xkb": "ru", "variant": ""},
    {"steam": "french", "kind": "xkb", "xkb": "fr", "variant": ""},
    {"steam": "japanese", "kind": "native", "xkb": None, "variant": ""},
])
rep = json.load(open(m.LANG_STATUS))
st = {l["steam"]: l["status"] for l in rep["languages"]}
assert st == {"russian": "synced", "french": "kde-layout-missing", "japanese": "steam-native"}, st
assert any("french" in l for l in logged)
assert rep["kde_layouts"] == ["us", "ru", "de", "us(intl)"]
print("ok")
