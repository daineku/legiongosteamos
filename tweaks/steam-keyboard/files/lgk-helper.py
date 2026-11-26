#!/usr/bin/env python3
"""lgk-helper: Desktop Mode glue for the ORIGINAL Steam on-screen keyboard on the Legion Go.

Runs only inside the Plasma session (systemd --user unit PartOf=plasma-workspace.target), so Gaming
Mode never sees it. It does two things, both event-driven (no polling):

 1. Injects src/lgk-inject.js into Steam's SharedJSContext through Steam's local CEF debugger
    (127.0.0.1:8080, enabled by ~/.local/share/Steam/.cef-enable-remote-debugging, which Decky
    already uses). Re-injects when Steam (re)starts (inotify on ~/.steam/steam.pid) or when the
    Steam UI context is recreated (CDP Runtime.executionContextCreated). Nothing on disk is patched.

 2. Auto-open state machine, driven by AT-SPI accessibility focus events
    ("object:state-changed:focused"). Only the *kind* of the focused widget is inspected
    (EDITABLE state, not READ_ONLY) plus an opaque identity (pid + object path) - never its text.
    KWin's VirtualKeyboard "activeClientSupportsTextInput" is unusable here: it is per client and
    stays true for every Qt/GTK app, so moving between fields or apps produces no edge.

      HIDDEN_READY --editable field focused--> open keyboard (bottom) -> VISIBLE_BOTTOM
      VISIBLE_BOTTOM <--toggle key--> VISIBLE_TOP
      VISIBLE_* --keyboard closed while an editable field has focus--> HIDDEN_MANUALLY_DISMISSED(field)
      VISIBLE_* --keyboard closed otherwise--------------------------> HIDDEN_READY
      HIDDEN_MANUALLY_DISMISSED --focus leaves that field-----------> HIDDEN_READY (and opens at once
                                                                       if focus landed on another field)
      any state --manual open (Steam button/menu)--------------------> VISIBLE_BOTTOM

    No timeouts: suppression ends only when focus really leaves the dismissed field. Taps and typing
    inside the same field produce no focus event, so they cannot undo Hide. The keyboard window
    never takes focus (KWin wantsInput=false).
    The helper switches the AT-SPI bus "IsEnabled" flag on while it runs (apps then publish focus
    events) and restores the previous value on exit.

Never reads, receives or logs typed text.
"""
import base64, ctypes, ctypes.util, fcntl, glob, json, os, signal, socket, struct, sys, urllib.request

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)   # PyGObject API churn; keep the journal clean

import gi
gi.require_version("Gio", "2.0")
gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, Gio, GLib

HERE = os.path.dirname(os.path.realpath(__file__))
INJECT_JS = os.path.join(HERE, "lgk-inject.js")
DISABLE_FLAG = os.path.expanduser("~/.config/legiongo-steamos/steam-keyboard/lgk-disabled")
AUTOOPEN_OFF_FLAG = os.path.expanduser("~/.config/legiongo-steamos/steam-keyboard/lgk-autoopen-off")
DOUBLESPACE_OFF_FLAG = os.path.expanduser("~/.config/legiongo-steamos/steam-keyboard/lgk-doublespace-off")
CDP = ("127.0.0.1", 8080)
RUNTIME_STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "lgk-helper.state")  # for --cleanup
# Multilingual Input Support: last seen Steam keyboard languages and their KDE/XKB status (read by `legiongo.sh status`)
LANG_STATUS = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "lgk-languages.json")
STEAM_DIR = os.path.expanduser("~/.steam")
DEBUG = "--debug" in sys.argv

HIDDEN_READY, VISIBLE_BOTTOM, VISIBLE_TOP, HIDDEN_DISMISSED = (
    "HIDDEN_READY", "VISIBLE_BOTTOM", "VISIBLE_TOP", "HIDDEN_MANUALLY_DISMISSED")


def log(*a):
    print("lgk:", *a, flush=True)


def dbg(*a):
    if DEBUG:
        log(*a)


# ------------------------------------------------------------------ minimal CDP websocket client
class CDPConn:
    def __init__(self, ws_url, on_message, on_close):
        path = ws_url.split(f":{CDP[1]}", 1)[1]
        self.sock = socket.create_connection(CDP, timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f"GET {path} HTTP/1.1\r\nHost: {CDP[0]}:{CDP[1]}\r\nUpgrade: websocket\r\n"
                           f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
                           f"Sec-WebSocket-Version: 13\r\n\r\n").encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            d = self.sock.recv(4096)
            if not d:
                raise ConnectionError("handshake closed")
            buf += d
        if b" 101 " not in buf.split(b"\r\n", 1)[0]:
            raise ConnectionError(buf[:120])
        self.buf = buf.split(b"\r\n\r\n", 1)[1]
        self.frag = b""
        self.sock.setblocking(False)
        self.on_message, self.on_close = on_message, on_close
        self.next_id = 0
        self.pending = {}
        self.closed = False
        self.watch = GLib.io_add_watch(self.sock.fileno(), GLib.PRIORITY_DEFAULT,
                                       GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self._readable)
        GLib.idle_add(self._drain)

    def call(self, method, cb=None, **params):
        self.next_id += 1
        if cb:
            self.pending[self.next_id] = cb
        data = json.dumps({"id": self.next_id, "method": method, "params": params}).encode()
        n = len(data)
        hdr = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else
                               bytes([0xFE]) + struct.pack(">H", n) if n < 65536 else
                               bytes([0xFF]) + struct.pack(">Q", n))
        mask = os.urandom(4)
        payload = bytes(b ^ mask[i & 3] for i, b in enumerate(data))
        self.sock.setblocking(True)
        try:
            self.sock.sendall(hdr + mask + payload)
        finally:
            self.sock.setblocking(False)

    def evaluate(self, expr, cb=None):
        def done(msg):
            if cb:
                res = msg.get("result", {})
                cb(res.get("result", {}).get("value"), res.get("exceptionDetails"))
        self.call("Runtime.evaluate", done, expression=expr, returnByValue=True, awaitPromise=False)

    def _readable(self, fd, cond):
        if cond & (GLib.IO_HUP | GLib.IO_ERR):
            self.close()
            return False
        try:
            d = self.sock.recv(65536)
        except BlockingIOError:
            return True
        except OSError:
            d = b""
        if not d:
            self.close()
            return False
        self.buf += d
        self._drain()
        return True

    def _drain(self):
        while True:
            if len(self.buf) < 2:
                return False
            b1, b2 = self.buf[0], self.buf[1]
            n, off = b2 & 0x7F, 2
            if n == 126:
                if len(self.buf) < 4: return False
                n, off = struct.unpack(">H", self.buf[2:4])[0], 4
            elif n == 127:
                if len(self.buf) < 10: return False
                n, off = struct.unpack(">Q", self.buf[2:10])[0], 10
            if len(self.buf) < off + n:
                return False
            payload, self.buf = self.buf[off:off + n], self.buf[off + n:]
            op = b1 & 0x0F
            if op == 0x8:
                self.close()
                return False
            if op in (0x1, 0x0, 0x2):
                self.frag += payload
                if b1 & 0x80:
                    msg, self.frag = self.frag, b""
                    try:
                        m = json.loads(msg)
                    except ValueError:
                        continue
                    cb = self.pending.pop(m.get("id"), None) if "id" in m else None
                    if cb:
                        cb(m)
                    elif "method" in m:
                        self.on_message(m)

    def close(self):
        if self.closed:
            return
        self.closed = True
        try:
            GLib.source_remove(self.watch)
        except Exception:
            pass
        try:
            self.sock.close()
        except OSError:
            pass
        self.on_close()


# ------------------------------------------------------------------ inotify (steam.pid rewrites)
IN_CLOSE_WRITE, IN_MOVED_TO, IN_CREATE = 0x08, 0x80, 0x100
libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)


def watch_steam_pid(callback):
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        log("inotify unavailable; Steam restarts are only noticed through reconnect backoff")
        return
    os.makedirs(STEAM_DIR, exist_ok=True)
    libc.inotify_add_watch(fd, STEAM_DIR.encode(), IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE)

    def readable(_fd, _cond):
        hit = False
        try:
            data = os.read(fd, 4096)
        except BlockingIOError:
            return True
        i = 0
        while i + 16 <= len(data):
            _wd, _mask, _cookie, ln = struct.unpack_from("iIII", data, i)
            name = data[i + 16:i + 16 + ln].split(b"\0", 1)[0]
            i += 16 + ln
            if name == b"steam.pid":
                hit = True
        if hit:
            callback()
        return True
    GLib.io_add_watch(fd, GLib.PRIORITY_DEFAULT, GLib.IO_IN, readable)



# ------------------------------------------------------------------ dual-stick / touchpad bridge
# While the keyboard is open, Steam switches the controller to its built-in "Keyboard" action set
# (app 769). Steam ignores user layouts for it, and it binds the touchpad to the right key cursor
# and the left stick to focus navigation. Without patching Steam, the bridge:
#   * reads the virtual Deck controller reports (InputPlumber deck-uhid, 28DE:12FE) read-only,
#     ONLY while the keyboard is visible (fd closed otherwise, so nothing runs when it is hidden);
#   * sends stick positions to the keyboard's own trackpad-cursor input (left stick -> left cursor,
#     right stick -> right cursor); L2/R2 then press the key under the cursor natively;
#   * drives a small uinput relative mouse from the touchpad (motion + click), so the pad stays
#     the desktop pointer; the keyboard is told to ignore the pad meanwhile.
# Report layout as in the kernel's hid-steam driver (Deck report type 0x09).
DECK_HID_ID = "0003:000028DE:000012FE"
RPAD_TOUCH_BIT, RPAD_CLICK_BIT = 1 << 20, 1 << 18
R2_BIT, L2_BIT = 1 << 0, 1 << 1
R3_BIT = 1 << 26
DPAD_BITS = ((1 << 8, 103), (1 << 9, 106), (1 << 10, 105), (1 << 11, 108))   # up right left down -> KEY_*
CURSOR_GRACE_S = 0.12      # the keyboard keeps a stick cursor alive ~100 ms after the stick is released
STICK_DEADZONE = 0.15
STICK_SEND_S = 0.02
PAD_GAIN = float(os.environ.get("LGK_PAD_GAIN", "0.016"))   # device units per pad unit (libinput adds accel)


def led_press_color():
    """Pressed-key colour for the on-screen keyboard: the joystick-ring LED colour, slightly deepened.
    Falls back to deep red when the LED can't be read or is black."""
    led = "/sys/class/leds/go:rgb:joystick_rings"
    try:
        idx = open(led + "/multi_index").read().split()
        val = [int(v) for v in open(led + "/multi_intensity").read().split()]
        mx = max(1, int(open(led + "/max_brightness").read().strip() or 100))
        c = dict(zip(idx, val))
        rgb = [min(255, round(c.get(k, 0) * 255 / mx * 0.8)) for k in ("red", "green", "blue")]
        if max(rgb) >= 40:
            return "rgb(%d, %d, %d)" % tuple(rgb)
    except (OSError, ValueError):
        pass
    return "rgb(204, 0, 0)"


class UInputMouse:
    UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT = 0x40045564, 0x40045565, 0x40045566
    UI_DEV_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405C5503, 0x5501, 0x5502
    EV_SYN, EV_KEY, EV_REL, REL_X, REL_Y, BTN_LEFT, BTN_RIGHT = 0, 1, 2, 0, 1, 0x110, 0x111

    def __init__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK | os.O_CLOEXEC)
        for ev in (self.EV_KEY, self.EV_REL):
            fcntl.ioctl(self.fd, self.UI_SET_EVBIT, ev)
        # mouse buttons, d-pad arrows, and the main key block (KEY_ESC..KEY_CAPSLOCK incl. LEFTSHIFT)
        # for physical long-press chords from the on-screen keyboard
        for k in (self.BTN_LEFT, self.BTN_RIGHT) + tuple(code for _, code in DPAD_BITS) + tuple(range(1, 59)) + tuple(range(102, 112)):
            fcntl.ioctl(self.fd, self.UI_SET_KEYBIT, k)
        for r in (self.REL_X, self.REL_Y):
            fcntl.ioctl(self.fd, self.UI_SET_RELBIT, r)
        setup = struct.pack("HHHH80sI", 0x06, 0x1209, 0x4C47, 1, b"lgk touchpad pointer (keyboard open)", 0)
        fcntl.ioctl(self.fd, self.UI_DEV_SETUP, setup)
        fcntl.ioctl(self.fd, self.UI_DEV_CREATE)

    def _ev(self, t, c, v):
        return struct.pack("llHHi", 0, 0, t, c, v)

    def move(self, dx, dy):
        try:
            os.write(self.fd, self._ev(self.EV_REL, self.REL_X, dx) + self._ev(self.EV_REL, self.REL_Y, dy) +
                     self._ev(self.EV_SYN, 0, 0))
        except OSError:
            pass

    def key(self, code, down):
        try:
            os.write(self.fd, self._ev(self.EV_KEY, code, 1 if down else 0) + self._ev(self.EV_SYN, 0, 0))
        except OSError:
            pass

    def chord(self, code, shift):
        KEY_LEFTSHIFT = 42
        if shift:
            self.key(KEY_LEFTSHIFT, True)
        self.key(code, True)
        self.key(code, False)
        if shift:
            self.key(KEY_LEFTSHIFT, False)

    def button(self, down, code=None):
        self.key(self.BTN_LEFT if code is None else code, down)

    def close(self):
        try:
            fcntl.ioctl(self.fd, self.UI_DEV_DESTROY)
            os.close(self.fd)
        except OSError:
            pass


class PadBridge:
    def __init__(self, send_js):
        self.send_js = send_js
        self.fd = None
        self.watch = 0
        self.mouse = None
        self.reset()

    def reset(self):
        self.touch = False
        self.last = None
        self.acc = [0.0, 0.0]
        self.clicked = False
        self.sticks_active = False
        self.last_send = 0.0
        self.btn = 0
        self.held = set()                 # uinput keys/buttons currently pressed by the bridge
        self.trig_mouse = {}              # trigger bit -> mouse button it pressed
        self.cursor_seen = {"l": 0.0, "r": 0.0}

    @staticmethod
    def find_hidraw():
        for dev in glob.glob("/sys/class/hidraw/hidraw*"):
            try:
                if DECK_HID_ID in open(os.path.join(dev, "device", "uevent")).read():
                    return "/dev/" + os.path.basename(dev)
            except OSError:
                pass
        return None

    def start(self):
        if self.fd is not None:
            self.send_js("window.__LGK && __LGK.bridge(true)")   # idempotent; covers re-injection
            return
        path = self.find_hidraw()
        if not path:
            dbg("bridge: no deck-uhid hidraw")
            return
        try:
            if self.mouse is None:
                self.mouse = UInputMouse()
            self.fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
        except OSError as e:
            log("bridge unavailable:", e)
            return
        self.reset()
        self.watch = GLib.io_add_watch(self.fd, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR,
                                       self.readable)
        self.send_js("window.__LGK && __LGK.bridge(true)")
        self.send_js("window.__LGK && __LGK.setPressColor && __LGK.setPressColor(%s)" % json.dumps(led_press_color()))
        dbg("bridge on", path)

    def stop(self):
        if self.fd is None:
            return
        if self.mouse:
            for code in list(self.held):
                self.mouse.key(code, False)
            if self.clicked:
                self.mouse.button(False)
        if self.watch:
            GLib.source_remove(self.watch)
        os.close(self.fd)
        self.fd, self.watch = None, 0
        self.reset()
        self.send_js("window.__LGK && __LGK.bridge(false)")
        dbg("bridge off")

    def shutdown(self):
        self.stop()
        if self.mouse:
            self.mouse.close()
            self.mouse = None

    def readable(self, fd, cond):
        if cond & (GLib.IO_HUP | GLib.IO_ERR):
            self.watch = 0
            self.stop()
            return False
        try:
            d = os.read(fd, 64)
        except BlockingIOError:
            return True
        except OSError:
            self.watch = 0
            self.stop()
            return False
        if len(d) >= 56 and d[2] == 0x09:
            self.on_report(d)
        return True

    def on_report(self, d):
        btn = struct.unpack_from("<I", d, 8)[0]
        # ---- touchpad -> mouse
        touch = bool(btn & RPAD_TOUCH_BIT)
        x, y = struct.unpack_from("<hh", d, 20)
        if touch and self.touch and self.last:
            self.acc[0] += (x - self.last[0]) * PAD_GAIN
            self.acc[1] -= (y - self.last[1]) * PAD_GAIN      # pad Y grows upwards
            ix, iy = int(self.acc[0]), int(self.acc[1])
            if ix or iy:
                self.acc[0] -= ix
                self.acc[1] -= iy
                self.mouse.move(ix, iy)
        if touch != self.touch:
            self.acc = [0.0, 0.0]
        self.touch, self.last = touch, (x, y)
        click = bool(btn & RPAD_CLICK_BIT)
        if click != self.clicked:
            self.clicked = click
            self.mouse.button(click)
        # ---- sticks -> keyboard cursors
        lx, ly, rx, ry = (v / 32767.0 for v in struct.unpack_from("<hhhh", d, 48))
        l_on = lx * lx + ly * ly > STICK_DEADZONE ** 2
        r_on = rx * rx + ry * ry > STICK_DEADZONE ** 2
        now = GLib.get_monotonic_time() / 1e6
        if l_on:
            self.cursor_seen["l"] = now
        if r_on:
            self.cursor_seen["r"] = now
        # ---- triggers: press the key under an active stick cursor (the keyboard does that itself),
        #      otherwise act like the Desktop layout (L2 right click, R2 left click)
        changed = btn ^ self.btn
        for bit, side, code in ((L2_BIT, "l", UInputMouse.BTN_RIGHT), (R2_BIT, "r", UInputMouse.BTN_LEFT)):
            if not changed & bit:
                continue
            if btn & bit:
                # RT: always the desktop left click. LT: key under an active left cursor, else right click.
                if side == "r" or now - self.cursor_seen[side] > CURSOR_GRACE_S:
                    self.trig_mouse[bit] = code
                    self.mouse.key(code, True)
                    self.held.add(code)
            elif bit in self.trig_mouse:
                code = self.trig_mouse.pop(bit)
                self.mouse.key(code, False)
                self.held.discard(code)
        # ---- R3 (right stick click): press the key under the right stick cursor (RT is the mouse click)
        if changed & R3_BIT:
            self.send_js("window.__LGK && __LGK.rclick(%s)" % ("true" if btn & R3_BIT else "false"))
        # ---- d-pad: arrow keys (like the Desktop layout) instead of keyboard focus navigation
        for bit, code in DPAD_BITS:
            if changed & bit:
                self.mouse.key(code, bool(btn & bit))
                (self.held.add if btn & bit else self.held.discard)(code)
        self.btn = btn
        if l_on or r_on:
            if now - self.last_send >= STICK_SEND_S:
                self.last_send = now
                l = "%.3f,%.3f" % (lx, ly) if l_on else "null,null"
                r = "%.3f,%.3f" % (rx, ry) if r_on else "null,null"
                self.send_js("__LGK.stick(%s,%s)" % (l, r))
            self.sticks_active = True
        elif self.sticks_active:
            self.sticks_active = False
            self.send_js("__LGK.stick(null,null,null,null)")

# ------------------------------------------------------------------ helper
class Helper:
    def __init__(self):
        self.conn = None
        self.retry_src = 0
        self.retry_delay = 0.5
        self.retry_deadline = 0
        self.state = HIDDEN_READY
        self.field = None            # opaque identity of the focused editable widget, or None
        self.dismissed_field = None
        self.pending_open = False
        self.bridge = PadBridge(self.send_js)
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.terminal = False
        # Auto-open needs AT-SPI (accessibility focus events). Off (flag file) -> accessibility is left
        # alone entirely; terminal detection then comes from the KWin window class.
        self.autoopen = not os.path.exists(AUTOOPEN_OFF_FLAG)
        self.a11y_was_enabled = None
        if self.autoopen:
            self.a11y_was_enabled = self.a11y_enabled(None)
            if self.a11y_was_enabled is False:
                self.a11y_enabled(True)
        log("auto-open", "on" if self.autoopen else "off (accessibility not used)")
        self.win = None               # active window client geometry (x, y, w, h) from lgk-kwin.js
        self.active_class = ""        # active window resource class (e.g. "rustdesk")
        self.home_layout = None       # KDE layout index active before the keyboard synced its language
        self.caret = None             # caret/field rect of the focused field, window coordinates
        self.own_bus_name()
        self.write_state()                # before loading: a crash must never orphan the KWin script
        self.load_kwin_script()
        self.listener = None
        if self.autoopen:
            self.listener = Atspi.EventListener.new(self.on_focus_event)
            self.listener.register("object:state-changed:focused")
            self.listener.register("window:activate")
        watch_steam_pid(self.on_steam_pid)
        self.schedule_connect(0.1, budget_s=120)

    # ---------------- Steam / CDP
    def on_steam_pid(self):
        dbg("steam.pid rewritten")
        self.schedule_connect(1.0, budget_s=180)

    def schedule_connect(self, delay, budget_s=None):
        if budget_s is not None:
            self.retry_deadline = GLib.get_monotonic_time() / 1e6 + budget_s
            self.retry_delay = 0.5
        if self.retry_src:
            GLib.source_remove(self.retry_src)
        self.retry_src = GLib.timeout_add(int(delay * 1000), self.try_connect)

    def try_connect(self):
        self.retry_src = 0
        if self.conn and not self.conn.closed:
            return False
        if os.path.exists(DISABLE_FLAG):
            log("disabled by", DISABLE_FLAG)
            return False
        try:
            targets = json.load(urllib.request.urlopen(f"http://{CDP[0]}:{CDP[1]}/json", timeout=2))
            t = next(t for t in targets if t.get("type") == "page" and t.get("title") == "SharedJSContext")
            self.conn = CDPConn(t["webSocketDebuggerUrl"], self.on_cdp_event, self.on_cdp_close)
        except Exception as e:
            now = GLib.get_monotonic_time() / 1e6
            if now < self.retry_deadline:
                dbg("CDP not ready:", type(e).__name__)
                self.retry_delay = min(self.retry_delay * 1.6, 8)
                self.schedule_connect(self.retry_delay)
            else:
                dbg("giving up until Steam restarts")
            return False
        log("connected to Steam UI")
        self.conn.call("Runtime.enable")
        self.conn.call("Runtime.addBinding", name="lgkNotify")
        self.inject()
        return False

    def inject(self):
        try:
            js = open(INJECT_JS, encoding="utf-8").read()
        except OSError as e:
            log("cannot read inject script:", e)
            return
        def done(val, exc):
            if exc:
                log("inject failed:", json.dumps(exc)[:300])
            else:
                log(val)
                if self.bridge.fd is not None:
                    self.send_js("window.__LGK && __LGK.bridge(true)")
                # capability, known before any keyboard opens: the touchpad must never drive the keyboard's
                # cursors or Steam's focus navigation on dual-joystick devices (closes the race at keyboard open)
                self.send_js("window.__LGK && __LGK.setDualJoystick && __LGK.setDualJoystick(%s)"
                             % ("true" if PadBridge.find_hidraw() else "false"))
                self.send_js("window.__LGK && __LGK.setDoubleSpace && __LGK.setDoubleSpace(%s)"
                             % ("false" if os.path.exists(DOUBLESPACE_OFF_FLAG) else "true"))
                self.set_terminal(self.terminal)
                self.sync_state()
        self.conn.evaluate(js, done)

    def sync_state(self):
        def done(val, exc):
            if val is True and self.state not in (VISIBLE_BOTTOM, VISIBLE_TOP):
                self.set_state(VISIBLE_BOTTOM)
            elif val is False and self.state in (VISIBLE_BOTTOM, VISIBLE_TOP):
                self.set_state(HIDDEN_READY)
        self.conn.evaluate("window.__LGK ? __LGK.isOpen() : null", done)

    def on_cdp_close(self):
        log("Steam UI connection closed")
        self.conn = None
        if self.state in (VISIBLE_BOTTOM, VISIBLE_TOP):
            self.set_state(HIDDEN_READY)
        self.schedule_connect(2.0, budget_s=120)

    def on_cdp_event(self, m):
        meth = m.get("method")
        if meth == "Runtime.bindingCalled" and m["params"].get("name") == "lgkNotify":
            try:
                ev = json.loads(m["params"].get("payload") or "{}")
            except ValueError:
                return
            self.on_keyboard_event(ev)
        elif meth == "Runtime.executionContextCreated":
            ctx = m["params"].get("context", {})
            if ctx.get("auxData", {}).get("isDefault") and self.conn:
                # Steam UI reloaded inside the same process: bindings survive, script does not.
                GLib.timeout_add(1500, lambda: (self.conn and self.inject(), False)[1])

    # ---------------- state machine
    def set_state(self, s, why=""):
        if s != self.state:
            dbg(f"{self.state} -> {s} {why}")
            self.state = s
        if s in (VISIBLE_BOTTOM, VISIBLE_TOP):
            self.bridge.start()
        else:
            self.bridge.stop()

    def send_js(self, expr):
        if self.conn and not self.conn.closed:
            self.conn.call("Runtime.evaluate", expression=expr)

    def on_keyboard_event(self, ev):
        kind = ev.get("ev")
        if kind == "chord":                 # physical Shift+key for a long-pressed secondary symbol
            code = ev.get("scan")
            if isinstance(code, int) and (1 <= code <= 58 or 102 <= code <= 111) and code != 42 and self.bridge.mouse:
                self.bridge.mouse.chord(code, bool(ev.get("shift")))
            return
        if kind == "combo":                 # modifier-only shortcut (e.g. Alt+Shift): hold mods, tap key
            mods = [m for m in ev.get("mods", []) if m in (29, 42, 56)]
            key = ev.get("key")
            if key in (29, 42, 56) and self.bridge.mouse:
                for m in mods:
                    self.bridge.mouse.key(m, True)
                self.bridge.mouse.key(key, True)
                self.bridge.mouse.key(key, False)
                for m in reversed(mods):
                    self.bridge.mouse.key(m, False)
            return
        if kind == "layouts":               # Steam keyboard languages the user enabled (compatibility report)
            self.report_languages(ev.get("enabled") or [])
            return
        if kind == "lang":
            # remember the user's own KDE layout when the keyboard starts syncing, restore it on hide/exit
            if self.home_layout is None:
                self.home_layout = self.current_kde_layout()
            xkb = ev.get("xkb")
            ok = self.set_kde_layout(str(xkb), str(ev.get("variant") or "")) if xkb else self.restore_home_layout(keep=True)
            self.send_js("window.__LGK && (__LGK.kdeLayout = %s)" % json.dumps(xkb if (xkb and ok) else None))
            # the user tapped the language key while RustDesk is in front: switch the remote's input
            # language too (Windows Alt+Shift). Typed text itself is exact in Translate mode anyway.
            if ev.get("user") and self.active_class == "rustdesk" and self.bridge.mouse:
                m = self.bridge.mouse
                m.key(56, True); m.key(42, True); m.key(42, False); m.key(56, False)
                dbg("sent Alt+Shift to RustDesk")
            return
        if kind == "hidden":
            self.restore_home_layout()
        if kind == "shown":
            self.pending_open = False
            self.set_state(VISIBLE_TOP if ev.get("pos") == "top" else VISIBLE_BOTTOM, "(shown)")
        elif kind == "moved":
            self.set_state(VISIBLE_TOP if ev.get("pos") == "top" else VISIBLE_BOTTOM, "(moved)")
        elif kind == "hidden":
            self.pending_open = False
            why = "(closed, hide key)" if ev.get("hideKey") else "(closed)"
            if self.field is not None:
                self.dismissed_field = self.field
                self.set_state(HIDDEN_DISMISSED, why)
            else:
                self.set_state(HIDDEN_READY, why)


    # ---------------- active window geometry (KWin script -> D-Bus)
    BUS_XML = """<node><interface name="org.legiondesktop.lgk">
      <method name="ActiveWindow"><arg type="s" direction="in"/></method></interface></node>"""
    KWIN_SCRIPT = os.path.join(HERE, "lgk-kwin.js")
    KWIN_NAME = "lgk-activewindow-%d" % os.getpid()   # unique: KWin keeps stale names around

    def own_bus_name(self):
        info = Gio.DBusNodeInfo.new_for_xml(self.BUS_XML).interfaces[0]
        def call(conn, sender, path, iface, method, params, inv):
            if method == "ActiveWindow":
                try:
                    parts = params.unpack()[0].split(",")
                    v = tuple(float(x) for x in parts[:8])
                    if len(v) == 8:
                        self.win = v
                        self.active_class = parts[8].lower() if len(parts) > 8 else ""
                        self.send_js("window.__LGK && __LGK.setActiveClass && __LGK.setActiveClass(%s)" % json.dumps(self.active_class))
                        if not self.autoopen:
                            self.set_terminal(self.active_class in self.TERMINAL_CLASSES)
                except ValueError:
                    pass
            inv.return_value(None)
        self.bus.register_object("/lgk", info, call, None, None)
        Gio.bus_own_name_on_connection(self.bus, "org.legiondesktop.lgk", Gio.BusNameOwnerFlags.REPLACE, None, None)

    def kwin_scripting(self, method, args, sig):
        try:
            return self.bus.call_sync("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", method,
                                      GLib.Variant(sig, args) if sig else None, None,
                                      Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error as e:
            dbg("kwin scripting:", e.message)
            return None

    def load_kwin_script(self, tries=0):
        if tries == 0:
            self.kwin_scripting("unloadScript", (self.KWIN_NAME,), "(s)")
        r = self.kwin_scripting("loadScript", (self.KWIN_SCRIPT, self.KWIN_NAME), "(ss)")
        sid = r.unpack()[0] if r is not None else -1
        dbg("kwin script id", sid)
        if sid < 0:                       # previous instance still unloading: retry shortly (bounded)
            if tries < 10:
                GLib.timeout_add(300, lambda: (self.load_kwin_script(tries + 1), False)[1])
            return
        try:
            self.bus.call_sync("org.kde.KWin", "/Scripting/Script%d" % sid, "org.kde.kwin.Script", "run",
                               None, None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            try:   # older KWin: run via the Scripting object
                self.kwin_scripting("start", None, None)
            except Exception:
                pass

    @staticmethod
    def caret_rect(acc):
        """Raw window-relative rects of the field and of its caret. Positions only, never text.
        Chrome reports web content in device pixels (x2 on this screen), its own UI and Qt apps in
        logical pixels, so the scale is resolved later against the window size."""
        field = caret = None
        try:
            r = Atspi.Component.get_extents(acc, Atspi.CoordType.WINDOW)
            if r.height > 0:
                field = (r.x, r.y, r.width, r.height)
        except Exception:
            pass
        try:
            off = Atspi.Text.get_caret_offset(acc)
            for o in (off, off - 1):
                if o < 0:
                    continue
                r = Atspi.Text.get_character_extents(acc, o, Atspi.CoordType.WINDOW)
                if r.height > 0:
                    caret = (r.x, r.y, max(r.width, 1), r.height)
                    break
        except Exception:
            pass
        return (field, caret) if field or caret else None

    def caret_screen_js(self):
        """JS object literal with the caret's screen-y span, or 'null'."""
        if not self.caret or not self.win:
            return "null"
        wx, wy, ww, wh, area_top, area_bottom, scr_top, scr_bottom = self.win
        field, caret = self.caret

        def fit(r):
            if not r:
                return None, None
            for sc in (1, 2, 1.5, 1.25, 3):
                x, y, w, h = (v / sc for v in r)
                if -5 <= y and y + min(h, 80) <= wh + 5 and -5 <= x <= ww + 5:
                    return (x, y, w, h), sc
            return None, None
        f, fs = fit(field)
        c, _ = fit(caret)
        if f and c and not (f[1] - 2 <= c[1] <= f[1] + f[3] + 2):
            c = None                                  # caret inconsistent with its field: ignore it
        if c:
            top, bottom = c[1], c[1] + c[3]
        elif f:
            top, bottom = f[1], f[1] + min(f[3], 60)  # big text areas: their first lines
        else:
            return "null"
        return "{top:%d,bottom:%d,areaTop:%d,areaBottom:%d,screenBottom:%d}" % (
            wy + top, wy + bottom, area_top, area_bottom, scr_bottom)


    # ---------------- KDE active layout (follows the on-screen keyboard language)
    # ---------------- Multilingual Input Support: KDE/XKB layout follows the Steam keyboard language
    def kde_layouts(self):
        """[(layout, variant), ...] as configured in KDE, or None if KDE's keyboard service is unavailable."""
        try:
            v = self.bus.call_sync("org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts", "getLayoutsList",
                                   None, GLib.VariantType("(a(sss))"), Gio.DBusCallFlags.NONE, 1000, None)
            return [(l[0], l[1]) for l in v.unpack()[0]]
        except GLib.Error as e:
            dbg("KDE layouts:", e.message)
            return None

    def current_kde_layout(self):
        try:
            return self.bus.call_sync("org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts", "getLayout",
                                      None, GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
        except GLib.Error:
            return None

    @staticmethod
    def match_layout(layouts, code, variant=""):
        """Index of the KDE layout for XKB layout `code` + `variant` (exact variant match; "" = base layout)."""
        for i, (c, v) in enumerate(layouts or []):
            if c == code and (v or "") == (variant or ""):
                return i
        return None

    def set_kde_layout_index(self, idx):
        try:
            if self.current_kde_layout() != idx:
                self.bus.call_sync("org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts", "setLayout",
                                   GLib.Variant("(u)", (idx,)), None, Gio.DBusCallFlags.NONE, 1000, None)
            return True
        except GLib.Error as e:
            dbg("KDE layout:", e.message)
            return False

    def set_kde_layout(self, code, variant=""):
        """Switch KDE to the layout matching the Steam keyboard language. False if it is not configured in KDE
        (then nothing changes and the Steam keyboard keeps its own text path for that language)."""
        idx = self.match_layout(self.kde_layouts(), code, variant)
        if idx is None:
            dbg("KDE layout %s%s not configured" % (code, "(%s)" % variant if variant else ""))
            return False
        ok = self.set_kde_layout_index(idx)
        if ok:
            dbg("KDE layout ->", code, variant)
        return ok

    def restore_home_layout(self, keep=False):
        """Back to the KDE layout that was active before the keyboard started syncing."""
        if self.home_layout is not None:
            self.set_kde_layout_index(self.home_layout)
            if not keep:
                self.home_layout = None
        return True

    def report_languages(self, enabled):
        layouts = self.kde_layouts() or []
        out = []
        for e in enabled:
            if not isinstance(e, dict):
                continue
            kind, xkb, var = e.get("kind"), e.get("xkb"), e.get("variant") or ""
            if kind == "xkb":
                st = "synced" if self.match_layout(layouts, xkb, var) is not None else "kde-layout-missing"
            else:
                st = "steam-native"          # IME / languages Steam handles itself; no XKB layout involved
            out.append({"steam": e.get("steam"), "kind": kind, "xkb": xkb, "variant": var, "status": st})
            if st == "kde-layout-missing":
                log("Steam keyboard language %s: add the KDE layout '%s%s' for reliable input "
                    "(System Settings > Keyboard > Layouts)" % (e.get("steam"), xkb, "(%s)" % var if var else ""))
        try:
            with open(LANG_STATUS + ".tmp", "w") as f:
                json.dump({"languages": out, "kde_layouts": ["%s%s" % (c, "(%s)" % v if v else "") for c, v in layouts]}, f)
            os.replace(LANG_STATUS + ".tmp", LANG_STATUS)
        except OSError:
            pass

    # ---------------- AT-SPI
    def a11y_enabled(self, value):
        """Read (value=None) or set org.a11y.Status.IsEnabled on the accessibility bus launcher."""
        try:
            if value is None:
                v = self.bus.call_sync("org.a11y.Bus", "/org/a11y/bus", "org.freedesktop.DBus.Properties",
                                       "Get", GLib.Variant("(ss)", ("org.a11y.Status", "IsEnabled")),
                                       GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 1000, None)
                return bool(v.unpack()[0])
            self.bus.call_sync("org.a11y.Bus", "/org/a11y/bus", "org.freedesktop.DBus.Properties", "Set",
                               GLib.Variant("(ssv)", ("org.a11y.Status", "IsEnabled", GLib.Variant("b", value))),
                               None, Gio.DBusCallFlags.NONE, 1000, None)
            dbg("a11y IsEnabled ->", value)
        except GLib.Error as e:
            log("a11y bus:", e.message)
        return None

    def write_state(self):
        try:
            with open(RUNTIME_STATE, "w") as f:
                json.dump({"kwin_script": self.KWIN_NAME, "a11y_was_enabled": self.a11y_was_enabled}, f)
        except OSError:
            pass

    def shutdown(self):
        self.restore_home_layout()
        self.kwin_scripting("unloadScript", (self.KWIN_NAME,), "(s)")
        self.bridge.shutdown()
        if self.a11y_was_enabled is False:
            self.a11y_enabled(False)
        try:
            os.unlink(RUNTIME_STATE)
        except OSError:
            pass

    @staticmethod
    def field_of(acc):
        """Identity of an editable, writable widget; None for anything else. Never touches its text."""
        try:
            st = acc.get_state_set()
            if not st.contains(Atspi.StateType.EDITABLE) or st.contains(Atspi.StateType.READ_ONLY):
                return None
            return (acc.get_process_id(), acc.path)
        except Exception:
            return None

    TERMINAL_APPS = {"konsole", "yakuake", "kitty", "alacritty", "foot", "wezterm", "xterm", "gnome-terminal-server",
                     "org.gnome.console", "kgx", "terminator", "tilix", "ghostty"}

    TERMINAL_CLASSES = {"org.kde.konsole", "konsole", "org.kde.yakuake", "yakuake", "kitty", "alacritty", "foot",
                        "org.wezfurlong.wezterm", "xterm", "org.gnome.console", "gnome-terminal-server", "com.mitchellh.ghostty",
                        "terminator", "com.gexperts.tilix"}

    def set_terminal(self, on):
        if on != self.terminal:
            self.terminal = on
            dbg("terminal:", on)
        self.send_js("window.__LGK && __LGK.setTerminal && __LGK.setTerminal(%s)" % ("true" if on else "false"))

    def on_focus_event(self, e):
        try:
            if e.type.startswith("window:activate"):
                app = (e.source.get_application().get_name() or "").lower()
                self.set_terminal(app in self.TERMINAL_APPS)
                return
            if e.detail1:
                self.set_terminal(e.source.get_role_name() == "terminal")
            if e.detail1:
                f = self.field_of(e.source)
                self.caret = self.caret_rect(e.source) if f is not None else None
                self.on_field_focus(f)
            elif self.field is not None and self.field == self.field_of(e.source):
                self.on_field_focus(None)            # focus left the field (maybe to a non-a11y window)
        except Exception as ex:
            dbg("focus event error:", type(ex).__name__, str(ex)[:120])

    def on_field_focus(self, field):
        if field == self.field:
            return
        self.field = field
        dbg("focus:", "editable field" if field else "non-text", "| state", self.state,
            "| caret(screen y)", self.caret_screen_js() if field else "-", "| win", self.win)
        if self.state == HIDDEN_DISMISSED and field != self.dismissed_field:
            self.dismissed_field = None
            self.set_state(HIDDEN_READY, "(focus left the dismissed field)")
        if field is not None and self.state == HIDDEN_READY and not os.path.exists(AUTOOPEN_OFF_FLAG):
            self.open_keyboard()
        elif field is not None and self.state in (VISIBLE_BOTTOM, VISIBLE_TOP):
            self.send_js("window.__LGK && __LGK.avoid && __LGK.avoid(%s)" % self.caret_screen_js())

    def open_keyboard(self):
        if not self.conn or self.pending_open:
            return
        self.pending_open = True
        dbg("auto-open")
        # safety valve only for a lost "shown" message; not used for Hide suppression
        GLib.timeout_add(3000, lambda: (setattr(self, "pending_open", False), False)[1])
        def done(val, exc):
            if exc or val not in ("opening", "already"):
                self.pending_open = False
        self.conn.evaluate("window.__LGK ? __LGK.open(%s) : 'missing'" % self.caret_screen_js(), done)


def cleanup():
    """ExecStopPost: undo what a crashed helper may have left (KWin script, accessibility flag)."""
    try:
        st = json.load(open(RUNTIME_STATE))
    except (OSError, ValueError):
        return
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    try:
        bus.call_sync("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript",
                      GLib.Variant("(s)", (st.get("kwin_script", ""),)), None, Gio.DBusCallFlags.NONE, 2000, None)
    except GLib.Error:
        pass
    if st.get("a11y_was_enabled") is False:
        try:
            bus.call_sync("org.a11y.Bus", "/org/a11y/bus", "org.freedesktop.DBus.Properties", "Set",
                          GLib.Variant("(ssv)", ("org.a11y.Status", "IsEnabled", GLib.Variant("b", False))),
                          None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass
    try:
        os.unlink(RUNTIME_STATE)
    except OSError:
        pass


def main():
    if "--cleanup" in sys.argv:
        cleanup()
        return
    if os.environ.get("XDG_CURRENT_DESKTOP", "").upper().find("KDE") < 0 and "--force" not in sys.argv:
        log("not a Plasma session; exiting")
        return
    h = Helper()
    loop = GLib.MainLoop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, loop.quit)
    try:
        loop.run()
    finally:
        h.shutdown()


if __name__ == "__main__":
    main()
