#!/usr/bin/env python3
"""legion-tp-handover: single-owner touchpad routing for the Legion Go in KDE Desktop Mode.

Problem: SteamOS's steamos-manager sets InputPlumber's targets to [deck-uhid, keyboard, mouse], so the
touchpad reaches the desktop only through the Steam client. When Steam exits or crashes, the pad is dead.

Policy (exactly one pointer path at a time):
  Steam has the virtual Deck controller (uhid 28DE:12FE) open  -> no "touchpad" target (Steam drives the cursor)
  nobody named "steam" has it open                            -> add InputPlumber's "touchpad" target (KWin/libinput)

Event-driven, no polling:
  - inotify IN_OPEN/IN_CLOSE on the Deck hidraw node. A crashing process closes its fds, which also fires IN_CLOSE.
  - inotify IN_CREATE on /dev for hidraw*. This covers resume re-enumeration, InputPlumber restarts and
    steamos-manager re-applying its target list to a new CompositeDevice.
  Disabling the native pad happens immediately (Steam is back). Enabling waits ENABLE_DELAY_S, because
  Steam briefly closes and reopens the node during controller (re)configuration.
Only the "touchpad" entry is added or removed. Every other target (deck-uhid ...) stays as SteamOS set it,
and InputPlumber's SetTargetDevices only starts or stops the changed target.
On exit (session end, Gaming Mode switch, SIGTERM) the "touchpad" target is removed. The unit's
ExecStopPost repeats that even if this process crashes.
"""
import ctypes, ctypes.util, glob, os, select, signal, struct, subprocess, sys, time

ENABLE_DELAY_S = 2.0
RESCAN_DELAY_S = 3.0          # after hidraw hotplug: let InputPlumber/steamos-manager settle first
STEAM_COMMS = {"steam"}
IP = "org.shadowblip.InputPlumber"
CD_IFACE = "org.shadowblip.Input.CompositeDevice"
DEVICE_NAME = "Lenovo Legion Go"

IN_OPEN, IN_CLOSE_WRITE, IN_CLOSE_NOWRITE, IN_CREATE = 0x20, 0x08, 0x10, 0x100
IN_IGNORED, IN_NONBLOCK, IN_CLOEXEC = 0x8000, 0o4000, 0o2000000
libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)


def log(msg):
    print(msg, flush=True)


def busctl(*args):
    r = subprocess.run(["busctl", *args], capture_output=True, text=True, timeout=10)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def legion_composite():
    rc, out, _ = busctl("tree", "--list", IP)
    if rc:
        return None
    for path in out.split():
        if path.rsplit("/", 1)[-1].startswith("CompositeDevice"):
            rc, name, _ = busctl("get-property", IP, path, CD_IFACE, "Name")
            if rc == 0 and f'"{DEVICE_NAME}"' in name:
                return path
    return None


def target_types(cd):
    rc, out, _ = busctl("get-property", IP, cd, CD_IFACE, "TargetDevices")
    if rc:
        return None
    types = []
    for t in [w.strip('"') for w in out.split() if w.startswith('"/')]:
        rc, ty, _ = busctl("get-property", IP, t, "org.shadowblip.Input.Target", "DeviceType")
        if rc == 0:
            types.append(ty.split('"')[1])
    return types


def set_touchpad(want):
    cd = legion_composite()
    if not cd:
        return
    cur = target_types(cd)
    if cur is None or "deck-uhid" not in cur:
        log(f"targets {cur}: no deck-uhid, leaving untouched")
        return
    if ("touchpad" in cur) == want:
        return
    new = [t for t in cur if t != "touchpad"] + (["touchpad"] if want else [])
    rc, _, err = busctl("call", IP, cd, CD_IFACE, "SetTargetDevices", "as", str(len(new)), *new)
    log(f"{'ENABLE' if want else 'DISABLE'} native touchpad: {cur} -> {new}" + (f" FAILED: {err}" if rc else ""))


def deck_node():
    for h in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        dev = os.path.realpath(h + "/device")
        if "/uhid/" in dev and "28DE:12FE" in dev:
            return "/dev/" + os.path.basename(h)
    return None


def steam_holds(node):
    """True if a process named steam has `node` open (only steam-named processes are inspected)."""
    try:
        st = os.stat(node)
    except OSError:
        return False
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            with open(f"/proc/{p}/comm") as f:
                if f.read().strip() not in STEAM_COMMS:
                    continue
            for fd in os.listdir(f"/proc/{p}/fd"):
                try:
                    s = os.stat(f"/proc/{p}/fd/{fd}")
                except OSError:
                    continue
                if s.st_rdev == st.st_rdev and s.st_ino == st.st_ino:
                    return True
        except OSError:
            continue
    return False


class Inotify:
    def __init__(self):
        self.fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "inotify_init1")
        self.node_wd = None
        self.node = None
        self.dev_wd = self.add("/dev", IN_CREATE)

    def add(self, path, mask):
        wd = libc.inotify_add_watch(self.fd, path.encode(), mask)
        if wd < 0:
            raise OSError(ctypes.get_errno(), f"inotify_add_watch {path}")
        return wd

    def watch_node(self, node):
        if node == self.node:
            return
        if self.node_wd is not None:
            libc.inotify_rm_watch(self.fd, self.node_wd)
            self.node_wd = None
        self.node = node
        if node:
            self.node_wd = self.add(node, IN_OPEN | IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
            log(f"watching Steam controller node {node}")

    def read(self):
        """Return (node_event, hidraw_created)."""
        node_ev = created = False
        try:
            buf = os.read(self.fd, 65536)
        except BlockingIOError:
            return node_ev, created
        i = 0
        while i + 16 <= len(buf):
            wd, mask, _, ln = struct.unpack_from("iIII", buf, i)
            name = buf[i + 16:i + 16 + ln].split(b"\0", 1)[0].decode()
            i += 16 + ln
            if wd == self.dev_wd and name.startswith("hidraw"):
                created = True
            elif wd == self.node_wd:
                if mask & IN_IGNORED:       # node deleted
                    self.node_wd, self.node = None, None
                    created = True
                else:
                    node_ev = True
        return node_ev, created


def main():
    stop = []
    signal.signal(signal.SIGTERM, lambda *a: stop.append(1))
    signal.signal(signal.SIGINT, lambda *a: stop.append(1))
    ino = Inotify()
    enable_at = rescan_at = None
    rescan_at = time.monotonic()   # evaluate once at start
    log("legion-tp-handover started")
    try:
        while not stop:
            deadlines = [d for d in (enable_at, rescan_at) if d is not None]
            timeout = max(0.0, min(deadlines) - time.monotonic()) if deadlines else None
            try:
                r, _, _ = select.select([ino.fd], [], [], timeout)
            except InterruptedError:
                continue
            node_ev = False
            if r:
                node_ev, created = ino.read()
                if created:
                    rescan_at = time.monotonic() + RESCAN_DELAY_S
            now = time.monotonic()
            if rescan_at is not None and now >= rescan_at:
                rescan_at = None
                ino.watch_node(deck_node())
                node_ev = True
            if node_ev or (enable_at is not None and now >= enable_at):
                node = ino.node
                if node and steam_holds(node):
                    enable_at = None
                    set_touchpad(False)              # Steam owns the pad: hand over immediately
                elif enable_at is None:
                    enable_at = now + ENABLE_DELAY_S  # confirm Steam is really gone
                elif now >= enable_at:
                    enable_at = None
                    set_touchpad(True)
    finally:
        set_touchpad(False)
        log("legion-tp-handover stopped; SteamOS default targets restored")


if __name__ == "__main__":
    if "--restore" in sys.argv:          # used by ExecStopPost as a crash-safe cleanup
        set_touchpad(False)
        sys.exit(0)
    sys.exit(main())
