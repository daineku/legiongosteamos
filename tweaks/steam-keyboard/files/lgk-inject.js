/*
 * Legion Go Desktop Keyboard (LGK) — enhancements for the ORIGINAL Steam on-screen keyboard.
 *
 * Injected into Steam's SharedJSContext by lgk-helper.py (Plasma session only, never Gaming Mode).
 * Nothing on disk inside Steam is modified: every change lives in memory and disappears when
 * Steam restarts. If any internal Steam API this relies on is missing (Steam update), the
 * corresponding feature is skipped and the stock keyboard keeps working.
 *
 * Features (desktop standalone keyboard only):
 *   - fit window exactly to the keys and place it flush with the screen bottom (no gap)
 *   - Emoji key -> Move Up / Move Down toggle (Steam's own "hide keyboard" glyph, mirrored)
 *   - top position = immediately below the KDE panel (screen.availTop, i.e. _NET_WORKAREA)
 *   - "Move" secondary on the close key removed; close key labelled "Hide"
 *   - long press (500 ms) on the language key opens Steam's native emoji picker
 *   - semi-transparent key backgrounds (alpha on dark backgrounds only, same palette)
 *   - reports shown/hidden to the helper (auto-open state machine). Never reports typed text.
 */
(function () {
  "use strict";
  const VERSION = 40;
  const NS = "__LGK";
  const prev = window[NS];
  if (prev && prev.version === VERSION) return "lgk: already v" + VERSION;
  if (prev && prev.teardown) { try { prev.teardown(); } catch (e) {} }

  const CFG = {
    alpha: 0.78,            // resulting opacity of dark key surfaces (over the desktop)
    panelAlpha: 0.55,       // opacity of the keyboard panel between the keys
    darkLuma: 0.35,         // only backgrounds darker than this get alpha
    longPressMs: 500,       // language key long press -> emoji
    bsCharRepeats: 6,       // Backspace hold: this many fast single-character repeats ...
    bsCharMs: [[6, 80], [20, 50], [Infinity, 30]],    // char repeat interval by repeat count (stock: 200 ms)
    bsWordMs: [[12, 250], [20, 180], [Infinity, 120]], // word (Ctrl+Backspace) interval by repeat count
    // in terminals (Ctrl+Backspace deletes only one character there) the hold stays in character mode
    hiddenKeys: ["AltGr"],
    bottomKeyWidth: 52,     // px (keyboard CSS px) for the non-space keys of the bottom row; stock ~70  // keys removed from every layout (AltGr chars stay in long-press popups)
  };

  const L = {
    version: VERSION,
    enabled: true,
    pos: "bottom",          // reset to bottom on every keyboard open
    popup: null,            // Steam popup wrapper of the keyboard window
    inst: null,             // keyboard React component instance
    proto: null,
    originals: {},
    unsupported: [],
    suppressLayoutOnce: false,
    hideRequested: false,
    lpTimer: 0,
    cleanups: [],
  };
  window[NS] = L;

  const log = (...a) => { try { console.log("[LGK]", ...a); } catch (e) {} };
  const notify = (ev, extra) => {
    try {
      if (typeof window.lgkNotify === "function")
        window.lgkNotify(JSON.stringify(Object.assign({ ev, pos: L.pos }, extra || {})));
    } catch (e) {}
  };

  const isKbPopupName = (n) => typeof n === "string" && n.startsWith("SP Keyboard");
  const kbPopup = () => {
    try {
      for (const [name, p] of g_PopupManager.m_mapPopups) if (isKbPopupName(name)) return p;
    } catch (e) {}
    return null;
  };

  // ---------------------------------------------------------------- component lookup
  function findInstance(doc) {
    const el = doc && doc.querySelector("[data-key-row]");
    if (!el) return null;
    const fk = Object.keys(el).find((k) => k.startsWith("__reactFiber"));
    let f = fk && el[fk];
    for (let i = 0; f && i < 80; i++, f = f.return) {
      const s = f.stateNode;
      if (s && typeof s.TypeKeyInternal === "function" && typeof s.TypeKey === "function") return s;
    }
    return null;
  }

  const isOurs = (inst) => L.enabled && inst && inst.props && inst.props.bStandalone && L.inst === inst;

  function patchPrototype(proto) {
    if (L.proto) return;
    L.proto = proto;
    const wrap = (name, fn) => {
      const desc = Object.getOwnPropertyDescriptor(proto, name);
      if (!desc || typeof desc.value !== "function" || !desc.writable) { L.unsupported.push(name); return; }
      const orig = proto[name];
      L.originals[name] = orig;
      proto[name] = function (...args) {
        try { return fn.call(this, orig, ...args); }
        catch (e) { log("patch error", name, e); return orig.apply(this, args); }
      };
    };

    wrap("TypeKeyInternal", function (orig, e) {
      if (!isOurs(this) || !e) return orig.call(this, e);
      if (modCombo(this, e)) return;
      if ((L.mods.ctrl || L.mods.alt) && sendChord(this, e)) return;
      if (L.dryRun && !(this.constructor.s_keyToggleData || {})[e.strKey]) { L.dryLog.push(e.strKey); return; } // self-test: record, send nothing (toggles only change keyboard state)
      const k = e.strKey;
      if (k === "SwitchKeys_Steam") { togglePosition(); return; }
      if (k === "SwitchKeys_Layout" && L.suppressLayoutOnce) { L.suppressLayoutOnce = false; return; }
      if (k === "VKMove") return; // movement is handled exclusively by the toggle key
      if (k === "VKClose") L.hideRequested = true;
      return orig.call(this, e);
    });
    // UpdateWindowSize / RotateWindowPosition are auto-bound getters on this Steam build and
    // cannot be wrapped; Steam's resize is intercepted at Window.ResizeTo (see guardResize) and
    // VKMove (the only caller of RotateWindowPosition) is intercepted above.
    wrap("BIsKeyEnabled", function (orig, key) {
      if (isOurs(this) && (key === "VKMove" || CFG.hiddenKeys.includes(key))) return false;
      return orig.call(this, key);
    });

    // Long press on a key with a secondary symbol (0 -> ")"): Steam opens the extended-character
    // popup (base, shift symbol, AltGr symbols, extras). Releasing on the key itself normally types
    // the base character; type the secondary symbol instead (Apple behaviour). Sliding onto any
    // popup entry (e.g. the rouble sign on 8) still types that entry.
    // Backspace hold: words instead of characters after a short fast phase.
    wrap("TypeKey", function (orig, el) {
      if (!isOurs(this) || !el || !el.closest) return orig.call(this, el);
      const k = el.closest("[data-key]");
      if (!k) return orig.call(this, el);
      if (L.bsWord && k.getAttribute("data-key") === "Backspace") { deleteWord(); return; }
      // Steam keeps one long-press slot per input source (touch, mouse, gamepad...)
      const slot = !k.hasAttribute("parent-row") && k.hasAttribute("data-extended-chars") &&
        (this.m_rgLongPress || []).find((sl) => sl && sl.longPressRow !== null && sl.longPressRow !== undefined &&
          +k.getAttribute("data-key-row") === sl.longPressRow && +k.getAttribute("data-key-col") === sl.longPressCol);
      if (slot) {
        const lab = k.querySelector(":scope > div > span[class]");
        const sec = lab && lab.textContent;
        if (sec && sec.length === 1 && sec !== k.getAttribute("data-key")) {
          // KDE's active layout matches this keyboard language (syncLang), so the secondary symbol
          // is exactly what a real Shift+key produces there: send a genuine Shift press instead of
          // Steam's "shift state without a Shift key" (lost by RustDesk and other X11 apps).
          if (chordSecondary(this, k)) return;
          for (const it of k.ownerDocument.querySelectorAll("[parent-row]")) {
            if (it.getAttribute("data-key") === sec && +it.getAttribute("parent-row") === slot.longPressRow &&
                +it.getAttribute("parent-col") === slot.longPressCol) return orig.call(this, it);
          }
        }
      }
      return orig.call(this, el);
    });
    // no controller button glyphs (L2/R2/L3/X/Y) on the keys; stick cursors and triggers still work
    wrap("BShowGlyphs", function (orig, ...args) {
      return isOurs(this) ? false : orig.apply(this, args);
    });
    wrap("componentDidUpdate", function (orig, ...args) {
      const r = orig.apply(this, args);
      if (isOurs(this)) { syncMods(this); patchLayout(this); syncLang(this); }
      return r;
    });
    wrap("LongPressTimerExpired", function (orig, ...args) {
      let ht = null;
      try { ht = this.LongPressSlot ? this.LongPressSlot(...args).holdTarget : this.state && this.state.holdTarget; } catch (e) {}
      if (!isOurs(this) || !ht || ht.getAttribute("data-key") !== "Backspace") return orig.apply(this, args);
      const now = Date.now();
      if (now - (L.bsLast || 0) > 700) L.bsCount = 0;   // a new hold
      L.bsLast = now;
      L.bsCount = (L.bsCount || 0) + 1;
      const C = this.constructor, prev = C.s_longPressRepeatThreshold;
      L.bsWord = !L.terminal && L.bsCount > CFG.bsCharRepeats;
      const steps = L.bsWord ? CFG.bsWordMs : CFG.bsCharMs;
      C.s_longPressRepeatThreshold = steps.find(([n]) => L.bsCount <= n)[1];   // read synchronously by the re-arm
      try { return orig.apply(this, args); }
      finally { C.s_longPressRepeatThreshold = prev; L.bsWord = false; }
    });
  }


  // ---------------------------------------------------------------- Ctrl / Alt keys
  // Two stock-named toggle keys ("Control", "Alt") are inserted around the language key of the
  // bottom row. Steam already tracks them as toggles: tap = one-shot (next key), tap twice = lock,
  // finger held down = held (multi-touch). Steam never applies them to output, so while either is
  // active the real modifier is held down at OS level and keys are sent as physical key codes
  // (layout independent: Ctrl+C works on the Russian layout, Alt stays down for Alt+Tab).
  const SK = { LCTRL: 103, LALT: 100, LSHIFT: 101 };        // Steam key codes (HID usage based)
  const SCAN_TO_HID = {                                      // PC scancode (data-keycode) -> HID usage
    2: 30, 3: 31, 4: 32, 5: 33, 6: 34, 7: 35, 8: 36, 9: 37, 10: 38, 11: 39, 12: 45, 13: 46, 14: 42, 15: 43,
    16: 20, 17: 26, 18: 8, 19: 21, 20: 23, 21: 28, 22: 24, 23: 12, 24: 18, 25: 19, 26: 47, 27: 48, 28: 40,
    30: 4, 31: 22, 32: 7, 33: 9, 34: 10, 35: 11, 36: 13, 37: 14, 38: 15, 39: 51, 40: 52, 41: 53, 43: 49,
    44: 29, 45: 27, 46: 6, 47: 25, 48: 5, 49: 17, 50: 16, 51: 54, 52: 55, 53: 56, 57: 44, 1: 41, 86: 100,
  };
  const NAME_TO_HID = { ArrowRight: 79, ArrowLeft: 80, ArrowDown: 81, ArrowUp: 82, Backspace: 42, Enter: 40,
    Tab: 43, " ": 44, Escape: 41, Delete: 76, Home: 74, End: 77 };
  const tActive = (v) => (v & 7) !== 0;                      // same as Steam's toggle helpers
  const tAfterKey = (v) => ((v & 3) === 1 ? 0 : (v & 3)) | (v & 4);
  L.mods = { ctrl: false, alt: false, shift: false };
  function setKey(code, down) { if (L.dryRun) { L.dryLog.push((down ? "+" : "-") + code); return; } SteamClient.Input.ControllerKeyboardSetKeyState(code, down); }
  function syncMods(inst) {
    const ts = (inst && inst.state && inst.state.toggleStates) || {};
    const want = { ctrl: tActive(ts.Control || 0), alt: tActive(ts.Alt || 0) };
    want.shift = ((ts.Shift || 0) & 4) !== 0 && (want.ctrl || want.alt);   // finger held on Shift with Ctrl/Alt
    if (want.ctrl !== L.mods.ctrl) { setKey(SK.LCTRL, want.ctrl); L.mods.ctrl = want.ctrl; }
    if (want.alt !== L.mods.alt) { setKey(SK.LALT, want.alt); L.mods.alt = want.alt; }
    if (want.shift !== !!L.mods.shift) { setKey(SK.LSHIFT, want.shift); L.mods.shift = want.shift; }
  }
  function releaseMods() { syncMods(null); }
  function sendChord(inst, e) {
    const k = e.strKey;
    if (!k || k.startsWith("SwitchKeys_") || k.startsWith("VK") || k.startsWith("IME_")) return false;
    const C = inst.constructor;
    if (C.s_keyToggleData && C.s_keyToggleData[k]) return false;   // Shift/Ctrl/Alt themselves
    const ts = inst.state.toggleStates || {};
    const shift = tActive(ts.Shift || 0);
    // physical key via lgk-helper's uinput device when available (layout independent: Ctrl+C works on
    // the Russian layout); Steam's SetKeyState resolves US keysyms in the active layout instead.
    const EVDEV_FOR = { ArrowRight: 106, ArrowLeft: 105, ArrowDown: 108, ArrowUp: 103, Backspace: 14, Enter: 28,
      Tab: 15, " ": 57, Escape: 1, Delete: 111, Home: 102, End: 107 };
    const scan = EVDEV_FOR[k] || parseInt(e.strKeycode) || 0;
    if (L.bridgeOn && ((scan >= 1 && scan <= 58) || (scan >= 102 && scan <= 111)) && scan !== 42) {
      if (L.dryRun) L.dryLog.push("<chord scan=" + scan + " shift=" + shift + ">");
      else notify("chord", { scan, shift });
    } else {
      const hid = NAME_TO_HID[k] || SCAN_TO_HID[parseInt(e.strKeycode)];
      if (!hid) return false;
      if (shift) setKey(SK.LSHIFT, true);
      setKey(hid, true); setKey(hid, false);
      if (shift) setKey(SK.LSHIFT, false);
    }
    // consume one-shot toggles like a normal key press does (held/locked stay)
    inst.setState((d) => ({ ...d, toggleStates: { ...d.toggleStates, Shift: tAfterKey(d.toggleStates.Shift),
      Control: tAfterKey(d.toggleStates.Control), Alt: tAfterKey(d.toggleStates.Alt) } }));
    return true;
  }
  // Tab: Steam's last step for Tab is ControllerKeyboardSendText("\t"), a TEXT tab that Chromium
  // ignores (no keydown, no focus move), and it drops the Shift state. Steam's own pipeline is kept
  // (IBus round-trip, dead keys, ordering with the letters before it); only that final step is
  // replaced by a genuine Tab key (HID 43) through Steam's key-state API, with a real Left Shift for
  // Shift+Tab. The application then does its native Tab handling (browser focus navigation etc.).
  function installTabKey(inst) {
    const m = inst.props && inst.props.VirtualKeyboardManager;
    if (!m || typeof m.HandleVirtualKeyDown !== "function" || Object.prototype.hasOwnProperty.call(m, "HandleVirtualKeyDown")) {
      L.unsupported.push("Tab key"); return;
    }
    const orig = m.HandleVirtualKeyDown;
    const tab = function (key, shift, ...rest) {
      try {
        if (key === "Tab" && isOurs(L.inst) && !this.m_fnVROnTextEnteredOverride &&
            !(this.m_ActiveElementProps && this.m_ActiveElementProps.onTextEntered) &&
            !(this.BUseVRKeyboard && this.BUseVRKeyboard())) {   // Steam's own text fields keep the stock path
          if (L.dryRun) { L.dryLog.push(shift ? "<shift+tab>" : "<tab>"); return; }
          try { this.ResetDeadKeyState(); } catch (e) {}
          if (shift) setKey(SK.LSHIFT, true);
          setKey(NAME_TO_HID.Tab, true); setKey(NAME_TO_HID.Tab, false);
          if (shift) setKey(SK.LSHIFT, false);
          return;
        }
      } catch (e) { log("tab", e); }
      return orig.call(this, key, shift, ...rest);
    };
    m.HandleVirtualKeyDown = tab;                    // own property shadows the prototype method
    L.cleanups.push(() => { if (m.HandleVirtualKeyDown === tab) delete m.HandleVirtualKeyDown; });
  }
  L.layoutPatches = [];
  function patchLayout(inst) {
    const sl = inst.state && inst.state.standardLayout;
    if (!sl || typeof sl.rgLayout !== "function" || sl.rgLayout.__lgk) return;
    const orig = sl.rgLayout;
    const wrapped = function (opts, ...rest) {
      const rows = orig.call(this, opts, ...rest);
      try {
        if (!L.enabled || !opts || !opts.bStandalone || !Array.isArray(rows)) return rows;
        const last = rows[rows.length - 1];
        const i = Array.isArray(last) ? last.findIndex((x) => x && x.key === "SwitchKeys_Layout") : -1;
        if (i < 0 || last.some((x) => x && x.key === "Control")) return rows;
        const out = rows.slice();
        out[out.length - 1] = [...last.slice(0, i), { key: "Control", label: "Ctrl", type: 4, strLocDescription: "#KeyboardKey_LControl" },
          last[i], { key: "Alt", label: "Alt", type: 4, strLocDescription: "#KeyboardKey_LAlt" }, ...last.slice(i + 1)];
        return out;
      } catch (e) { return rows; }
    };
    wrapped.__lgk = true;
    sl.rgLayout = wrapped;
    L.layoutPatches.push([sl, orig]);
    inst.forceUpdate();
  }


  // ---------------------------------------------------------------- KDE layout follows the keyboard language
  // Steam types natively only characters that exist in KDE's ACTIVE layout; everything else goes
  // through a keymap-swap trick that Chrome and RustDesk lose (steam-for-linux#13644). lgk-helper
  // switches KDE's active layout (us/ru) to match the on-screen keyboard's language.
  const XKB_FOR = { russian: "ru", qwerty: "us" };
  function syncLang(inst) {
    const sl = inst.state && inst.state.standardLayout;
    if (!sl) return;
    const xkb = XKB_FOR[sl.name] || "us";
    if (xkb !== L.xkb) { const user = L.xkb !== null; L.xkb = xkb; notify("lang", { xkb, user }); }
  }



  // Physical key by grid position (Steam leaves data-keycode=0 on some layouts, e.g. Russian digits).
  // Both Steam layouts in use follow the standard ANSI grid row for row, as do the XKB us/ru layouts.
  const POS_SCAN = [
    [41, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 43],
    [58, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 28],
    [42, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54],
  ];
  function posScan(k) {
    const r = parseInt(k.getAttribute("data-key-row")), c = parseInt(k.getAttribute("data-key-col"));
    return (POS_SCAN[r] || [])[c];
  }

  function chordSecondary(inst, k) {
    const sl = inst.state && inst.state.standardLayout;
    if (!sl || !XKB_FOR[sl.name] || XKB_FOR[sl.name] !== L.xkb) return false;   // layouts not in sync
    // grid position first: Steam's data-keycode is 0 or wrong on some Russian keys ("." carries 43)
    // Steam's ControllerKeyboardSetKeyState is not physical (it resolves a US keysym in the ACTIVE
    // layout), so the chord goes through lgk-helper's uinput device: real evdev key + real Shift.
    if (!L.bridgeOn) return false;
    const scan = posScan(k) || parseInt(k.getAttribute("data-keycode")) || 0;   // PC scancode = evdev code here
    if (!(scan >= 1 && scan <= 58) || scan === 42) return false;
    const ts = inst.state.toggleStates || {};
    // keys with a secondary label are digits/punctuation (Caps Lock does not affect them): the secondary
    // symbol is the shifted one unless Shift is already active (then the labels are swapped)
    const needShift = !tActive(ts.Shift || 0);
    if (L.dryRun) L.dryLog.push("<chord scan=" + scan + " shift=" + needShift + ">");
    else notify("chord", { scan, shift: needShift });
    inst.setState((d) => ({ ...d, toggleStates: { ...d.toggleStates, Shift: tAfterKey(d.toggleStates.Shift),
      Control: tAfterKey(d.toggleStates.Control), Alt: tAfterKey(d.toggleStates.Alt) } }));
    return true;
  }


  // Modifier-only shortcuts (Windows Alt+Shift language switch, Ctrl+Shift...). Steam's Shift never
  // produces a real Shift press, so: tapping Shift while Ctrl/Alt is active taps a real Shift, and
  // tapping Ctrl/Alt while Shift is armed taps that modifier with a real Shift held.
  const EV = { Shift: 42, Control: 29, Alt: 56 };
  function modCombo(inst, e) {
    const k = e.strKey;
    if (!EV[k] || !L.bridgeOn) return false;
    const ts = inst.state.toggleStates || {};
    let msg = null;
    if (k === "Shift" && (L.mods.ctrl || L.mods.alt)) msg = { mods: [], key: 42 };          // Ctrl/Alt already held
    else if ((k === "Alt" || k === "Control") && tActive(ts.Shift || 0) && !L.mods.ctrl && !L.mods.alt)
      msg = { mods: [42], key: EV[k] };
    if (!msg) return false;
    if (L.dryRun) L.dryLog.push("<combo " + JSON.stringify(msg) + ">"); else notify("combo", msg);
    inst.setState((d) => ({ ...d, toggleStates: { ...d.toggleStates, Shift: tAfterKey(d.toggleStates.Shift),
      Control: tAfterKey(d.toggleStates.Control), Alt: tAfterKey(d.toggleStates.Alt) } }));
    return true;
  }

  function deleteWord() {
    if (L.dryRun) { L.dryLog.push("<word>"); return; }
    const SI = SteamClient.Input;                    // Steam key codes: 103 LControl, 42 Backspace
    SI.ControllerKeyboardSetKeyState(103, true);
    SI.ControllerKeyboardSetKeyState(42, true);
    SI.ControllerKeyboardSetKeyState(42, false);
    SI.ControllerKeyboardSetKeyState(103, false);
  }

  // ---------------------------------------------------------------- geometry
  let fitBusy = false, fitAgain = false;
  function scheduleFit() {
    if (fitBusy) { fitAgain = true; return; }
    fitBusy = true;
    fit().catch((e) => log("fit failed", e)).finally(() => {
      fitBusy = false;
      if (fitAgain) { fitAgain = false; scheduleFit(); }
    });
  }

  async function fit() {
    const p = L.popup && L.popup.m_popup;
    if (!p || p.closed) return;
    const d = p.document, W = p.SteamClient && p.SteamClient.Window;
    if (!W || !W.ResizeTo || !W.MoveTo) { L.unsupported.push("Window.MoveTo/ResizeTo"); return; }
    const basic = d.querySelector(".BasicUI");
    const theme = d.querySelector(".DefaultTheme") || (basic && basic.firstElementChild && basic.firstElementChild.firstElementChild);
    if (!basic || !theme) return;
    const zoom = () => parseFloat(p.getComputedStyle(basic).zoom) || 1;
    const sleep = (ms) => new Promise((r) => p.setTimeout(r, ms));
    const measure = () => {
      const z = zoom();
      let t = Infinity, b = -Infinity;
      for (const k of d.querySelectorAll("[data-key-row] > div")) {
        const r = k.getBoundingClientRect();
        if (r.height < 5 || r.width < 5) continue;
        if (r.top < t) t = r.top;
        if (r.bottom > b) b = r.bottom;
      }
      return isFinite(t) ? { t: t * z, b: b * z } : null;
    };
    // the theme element is shifted (it is inside BasicUI's overflow:hidden box, so the
    // outer container must not be translated — that would clip the bottom row)
    let ty = parseFloat(theme.dataset.lgkTy || "0");
    for (let i = 0; i < 4; i++) {
      const m = measure();
      if (!m) return;
      const H = Math.round(m.b - m.t);
      ty = ty - m.t;
      theme.style.transform = ty ? `translateY(${ty / zoom()}px)` : "";
      theme.dataset.lgkTy = String(ty);
      const Wd = p.screen.availWidth || p.screen.width;          // edge to edge
      L.lastH = H;
      if (Math.abs(H - p.innerHeight) < 1 && Math.abs(m.t) < 0.5 && p.innerWidth === Wd) break;
      if (H > 40 && (H !== p.innerHeight || p.innerWidth !== Wd)) { L.ourResize = true; try { W.ResizeTo(Wd, H, true); } finally { L.ourResize = false; } await sleep(60); }
      else await sleep(16);
    }
    place();
  }

  function place() {
    const p = L.popup && L.popup.m_popup;
    if (!p || p.closed) return;
    const s = p.screen;
    const areaTop = s.availTop || 0;
    const areaBottom = (s.availTop || 0) + (s.availHeight || s.height);
    // bottom: flush with the screen edge unless a panel occupies the bottom (then sit above it)
    const bottomEdge = areaBottom < s.height ? areaBottom : s.height;
    const y = L.pos === "top" ? areaTop : bottomEdge - p.innerHeight;
    const x = (s.availLeft || 0) + Math.round(((s.availWidth || s.width) - p.innerWidth) / 2);
    p.SteamClient.Window.MoveTo(Math.max(0, x), Math.max(0, Math.round(y)), true);
    const root = p.document.documentElement;
    root.classList.toggle("lgk-top", L.pos === "top");
    root.classList.toggle("lgk-bottom", L.pos !== "top");
  }

  function togglePosition() {
    L.pos = L.pos === "top" ? "bottom" : "top";
    place();
    notify("moved");
  }

  // Steam's UpdateWindowSize grows the window back to its default height (the cause of the
  // bottom gap); route its resize requests to our exact fit instead.
  function guardResize(p) {
    const W = p.SteamClient && p.SteamClient.Window;
    if (!W || W.__lgkGuard) return;
    const desc = Object.getOwnPropertyDescriptor(W, "ResizeTo");
    if (!desc || !desc.writable) { L.unsupported.push("Window.ResizeTo guard"); return; }
    const orig = W.ResizeTo;
    W.ResizeTo = function (...a) {
      if (L.ourResize || !L.enabled || L.popup?.m_popup !== p) return orig.apply(W, a);
      scheduleFit();
    };
    W.__lgkGuard = orig;
  }

  // ---------------------------------------------------------------- styling
  function svgToMaskUrl(svgEl) {
    if (!svgEl) return null;
    const c = svgEl.cloneNode(true);
    c.removeAttribute("class");
    c.setAttribute("xmlns", "http://www.w3.org/2000/svg");
    c.querySelectorAll("[fill]").forEach((n) => { if (n.getAttribute("fill") !== "none") n.setAttribute("fill", "#000"); });
    c.querySelectorAll("path,rect,polygon,circle").forEach((n) => { if (!n.getAttribute("fill")) n.setAttribute("fill", "#000"); });
    return 'url("data:image/svg+xml,' + encodeURIComponent(c.outerHTML) + '")';
  }

  function injectStyle(d) {
    if (d.getElementById("lgk-style")) return;
    const closeSvg = d.querySelector('[data-key="VKClose"] svg');
    const mask = svgToMaskUrl(closeSvg);
    const paste = d.querySelector('[data-key="VKPaste"] span') || d.querySelector('[data-key="VKPaste"] > div');
    const labelSize = paste ? d.defaultView.getComputedStyle(paste).fontSize : "12px";
    const st = d.createElement("style");
    st.id = "lgk-style";
    st.textContent = `
      :root { ${mask ? `--lgk-move-icon: ${mask};` : ""} --lgk-label-size: ${labelSize}; }
      /* toggle key: Steam's keyboard/arrow glyph; mirrored (arrow up) while at the bottom */
      [data-key="SwitchKeys_Steam"] > div > * { visibility: hidden; }
      [data-key="SwitchKeys_Steam"] > div { position: relative; }
      [data-key="SwitchKeys_Steam"] > div::after {
        content: ""; position: absolute; left: 50%; top: 50%;
        width: 24px; height: 24px; margin: -12px 0 0 -12px;
        background-color: currentColor;
        -webkit-mask: var(--lgk-move-icon) center / contain no-repeat;
        transform: scaleY(-1); pointer-events: none;
      }
      :root.lgk-top [data-key="SwitchKeys_Steam"] > div::after { transform: none; }
      /* no gap between the screen edges and the outermost keys (letters get the width) */
      [class*="Layout_"] { padding-left: 0 !important; padding-right: 0 !important; }
      [class*="Row_"] > :first-child > [data-key-row] { padding-left: 0 !important; }
      [class*="Row_"] > :last-child > [data-key-row] { padding-right: 0 !important; }
      /* bottom row (the row holding Hide): narrower side keys so the spacebar stays wide */
      [class*="Row_"]:has([data-key="VKClose"]) [data-key-row][class]:not([data-key=" "]):not([parent-row]),
      [class*="Row_"]:has([data-key="VKClose"]) [data-key-row][class]:not([data-key=" "]):not([parent-row]) > div {
        width: ${CFG.bottomKeyWidth}px !important; min-width: 0 !important;
      }
      /* close key: "Hide" (Move secondary is disabled in BIsKeyEnabled) */
      [data-key="VKClose"] > div > * { visibility: hidden; }
      [data-key="VKClose"] > div { position: relative; }
      [data-key="VKClose"] > div::after {
        content: "Hide"; position: absolute; inset: 0;
        display: flex; align-items: center; justify-content: center;
        font-size: var(--lgk-label-size, 12px); pointer-events: none;
      }
    `;
    st.textContent += "\n/* pressed key colour (matches the joystick LEDs, set by lgk-helper) */\n" + pressedCss(d);
    const tcss = transparencyCss(d);
    if (!tcss) L.unsupported.push("theme variables (transparency)");
    st.textContent += "\n/* transparency */\n" + tcss;
    d.head.appendChild(st);
  }

  // Semi-transparency: Steam's keyboard themes define every key surface as a CSS variable
  // (--key-background-color, --key-meta-background-color, ...). For each theme rule we emit an
  // override with the same selector (higher specificity via :root) where only DARK opaque
  // surfaces get alpha. Labels, glyphs, focus/pressed/toggle colours stay exactly as they are.
  function parseColor(v) {
    v = (v || "").trim();
    let m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(v);
    if (m) {
      let h = m[1]; if (h.length === 3) h = h.split("").map((c) => c + c).join("");
      return { r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16), a: 1 };
    }
    m = /^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/.exec(v);
    if (m) return { r: +m[1], g: +m[2], b: +m[3], a: m[4] == null ? 1 : m[4].endsWith("%") ? parseFloat(m[4]) / 100 : parseFloat(m[4]) };
    return null;
  }
  // Steam's default theme paints a pressed key rgb(26,159,255). Find those key rules (hashed class names
  // change between Steam builds) and paint them with --lgk-press instead (default: deep red).
  function pressedCss(d) {
    const out = [];
    const visit = (rules) => {
      for (const r of rules) {
        if (r.cssRules && !r.selectorText) { try { visit(r.cssRules); } catch (e) {} continue; }
        if (!r.style || !r.selectorText || !/DefaultTheme/.test(r.selectorText)) continue;
        if (r.style.getPropertyValue("background-color").replace(/\s/g, "") !== "rgb(26,159,255)") continue;
        out.push(r.selectorText.split(",").map((x) => ":root " + x.trim()).join(", ") +
                 " { background-color: var(--lgk-press, rgb(204, 0, 0)) !important; }");
      }
    };
    for (const sh of d.styleSheets) { try { visit(sh.cssRules); } catch (e) {} }
    if (!out.length && !L.unsupported.includes("pressed colour")) L.unsupported.push("pressed colour");
    return out.join("\n");
  }
  L.setPressColor = (css) => {
    L.pressColor = String(css || "");
    const p = L.popup && L.popup.m_popup;
    if (p && !p.closed && /^rgb\(\d+, ?\d+, ?\d+\)$/.test(L.pressColor)) p.document.documentElement.style.setProperty("--lgk-press", L.pressColor);
    return L.pressColor;
  };

  function transparencyCss(d) {
    const out = [];
    const visit = (rules) => {
      for (const r of rules) {
        if (r.cssRules && !r.selectorText) { try { visit(r.cssRules); } catch (e) {} continue; }
        if (!r.style || !r.selectorText || !r.style.getPropertyValue("--key-background-color")) continue;
        const decl = [];
        // The panel (--background-color) sits under every key, so a key's own alpha
        // stacks on top of it.  Pick key alpha/colour so that key-over-panel composites
        // to exactly CFG.alpha of the original key colour over the desktop.
        const A = CFG.alpha;
        const P = parseColor(r.style.getPropertyValue("--background-color"));
        const ac = P && P.a >= 0.99 ? CFG.panelAlpha : 0;
        if (ac) decl.push(`--background-color: rgba(${P.r}, ${P.g}, ${P.b}, ${ac}) !important;`);
        const ak = 1 - (1 - A) / (1 - ac);
        const comp = (k, pc) => Math.max(0, Math.min(255, Math.round((A * k - (1 - ak) * ac * pc) / ak)));
        for (let i = 0; i < r.style.length; i++) {
          const prop = r.style[i];
          if (!/^--key[\w-]*-background-color$/.test(prop)) continue;
          const c = parseColor(r.style.getPropertyValue(prop));
          if (!c || c.a < 0.99) continue;
          if ((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) / 255 > CFG.darkLuma) continue;
          const k = ac ? { r: comp(c.r, P.r), g: comp(c.g, P.g), b: comp(c.b, P.b) } : c;
          decl.push(`${prop}: rgba(${k.r}, ${k.g}, ${k.b}, ${ak.toFixed(3)}) !important;`);
        }
        if (decl.length)
          out.push(r.selectorText.split(",").map((x) => ":root " + x.trim()).join(", ") + " { " + decl.join(" ") + " }");
      }
    };
    for (const sh of d.styleSheets) { try { visit(sh.cssRules); } catch (e) {} }
    return out.join("\n");
  }

  // ---------------------------------------------------------------- language key long press
  function installLongPress(d) {
    const LANG = '[data-key="SwitchKeys_Layout"]';
    const clear = () => { if (L.lpTimer) { d.defaultView.clearTimeout(L.lpTimer); L.lpTimer = 0; } };
    const start = (ev) => {
      L.suppressLayoutOnce = false;
      const t = ev.target && ev.target.closest && ev.target.closest(LANG);
      if (!t) return;
      if (ev.type === "vgp_onbuttondown" && !(ev.detail && ev.detail.button === 1)) return; // OK button
      clear();
      L.lpTimer = d.defaultView.setTimeout(() => {
        L.lpTimer = 0;
        if (!isOurs(L.inst)) return;
        L.suppressLayoutOnce = true;            // the release must not also switch language
        L.originals.TypeKeyInternal.call(L.inst, { strKey: "SwitchKeys_Steam" }); // native emoji picker
        notify("emoji");
      }, CFG.longPressMs);
    };
    const end = () => clear();
    const opts = { capture: true, passive: true };
    for (const t of ["pointerdown", "vgp_onbuttondown"]) d.addEventListener(t, start, opts);
    for (const t of ["pointerup", "pointercancel", "vgp_onbuttonup"]) d.addEventListener(t, end, opts);
    L.cleanups.push(() => {
      for (const t of ["pointerdown", "vgp_onbuttondown"]) d.removeEventListener(t, start, opts);
      for (const t of ["pointerup", "pointercancel", "vgp_onbuttonup"]) d.removeEventListener(t, end, opts);
    });
  }

  // ---------------------------------------------------------------- popup lifecycle

  // ---------------------------------------------------------------- dual-stick cursors / touchpad
  // Fed by lgk-helper (it reads the controller's HID reports while the keyboard is visible).
  // Stick positions go into the keyboard's own trackpad-cursor input object, exactly where Steam
  // puts trackpad positions, so the stock cursors, key hover and L2/R2-press logic are reused.
  // While the bridge is on, the touchpad is the desktop mouse (helper uinput device), so the
  // keyboard ignores Steam's right-pad cursor/click for it.
  const LPAD_TOUCH = 19, RPAD_TOUCH = 21, RPAD_CLICK = 22;
  function installPadInput() {
    const ti = L.inst && L.inst.m_trackpadInput;
    if (!ti || typeof ti.OnAnalogPad !== "function") { if (!L.unsupported.includes("sticks")) L.unsupported.push("sticks"); return; }
    const own = {};
    const orig = {};
    for (const k of ["OnAnalogPad", "OnButtonDown", "OnButtonUp"]) {
      own[k] = Object.prototype.hasOwnProperty.call(ti, k) ? ti[k] : undefined;
      orig[k] = ti[k];
    }
    L.padStats = {};
    ti.OnAnalogPad = function (pad, x, y, idx) {
      if (pad === RPAD_TOUCH && L.bridgeOn && !L.fromStick && isOurs(L.inst)) return;
      return orig.OnAnalogPad.apply(this, arguments);
    };
    // While the bridge is on: d-pad = arrow keys and triggers = mouse clicks (sent by lgk-helper,
    // like the Desktop layout); a trigger still presses the key under an ACTIVE stick cursor.
    const DIRS = new Set([9, 10, 11, 12]), TRIG = { 7: "m_leftTrackpad", 8: "m_rightTrackpad" };
    const trigBlocked = {};
    const btnWrap = (k) => function (btn) {
      if (k === "OnButtonDown") L.padStats[btn] = (L.padStats[btn] || 0) + 1;
      if (L.bridgeOn && isOurs(L.inst)) {
        if (btn === RPAD_TOUCH || btn === RPAD_CLICK || DIRS.has(btn)) return;
        if (TRIG[btn]) {
          // RT is always the desktop left click while the keyboard is open (sent by lgk-helper);
          // LT presses the key under an active left cursor, otherwise right click.
          if (k === "OnButtonDown") trigBlocked[btn] = btn === 8 || !(L.inst[TRIG[btn]] && L.inst[TRIG[btn]].active);
          if (trigBlocked[btn]) { if (k === "OnButtonUp") trigBlocked[btn] = false; return; }
        }
      }
      return orig[k].apply(this, arguments);
    };
    ti.OnButtonDown = btnWrap("OnButtonDown");
    ti.OnButtonUp = btnWrap("OnButtonUp");
    L.padOrig = orig;
    L.padInput = ti;
    // Steam's global FocusNavController moves the key highlight with the d-pad; its handlers are locked,
    // so drop d-pad buttons at its input sources (only while our keyboard is open and the bridge is on).
    const fnc = window.FocusNavController;
    for (const src of (fnc && fnc.m_rgGamepadInputSources) || []) {
      if (!src || src === ti || typeof src.OnButtonDown !== "function") continue;
      const sOwn = {}, sOrig = {};
      for (const kk of ["OnButtonDown", "OnButtonUp"]) {
        sOwn[kk] = Object.prototype.hasOwnProperty.call(src, kk) ? src[kk] : undefined;
        sOrig[kk] = src[kk];
        try {
          src[kk] = function (btn) {
            if (L.bridgeOn && isOurs(L.inst) && DIRS.has(btn)) return;
            return sOrig[kk].apply(this, arguments);
          };
        } catch (e) { continue; }
      }
      L.cleanups.push(() => { for (const kk of Object.keys(sOrig)) { try { if (sOwn[kk] === undefined) delete src[kk]; else src[kk] = sOwn[kk]; } catch (e) {} } });
    }
    L.cleanups.push(() => {
      for (const k of Object.keys(orig)) {
        if (own[k] === undefined) delete ti[k]; else ti[k] = own[k];
      }
      L.padInput = null; L.padOrig = null;
    });
  }
  L.dryLog = [];
  L.dry = (on) => { L.dryRun = !!on; L.dryLog = []; return L.dryRun; };
  L.terminal = false;
  L.setTerminal = (on) => { L.terminal = !!on; return L.terminal; };
  L.rclick = (down) => {
    const i = L.inst;
    if (!isOurs(i) || !i.m_rightTrackpad || (!i.m_rightTrackpad.active && down)) return false;
    try { i.HandleTrackpadClick(RPAD_CLICK, !!down); return true; } catch (e) { return false; }
  };
  L.bridge = (on) => { L.bridgeOn = !!on; return L.bridgeOn; };
  L.stick = (lx, ly, rx, ry) => {
    const ti = L.padInput;
    if (!ti || !isOurs(L.inst)) return;
    const idx = ti.m_nLastActiveControllerIndex;
    L.fromStick = true;
    try {
      if (lx !== null) L.padOrig.OnAnalogPad.call(ti, LPAD_TOUCH, lx, ly, idx);
      if (rx !== null) L.padOrig.OnAnalogPad.call(ti, RPAD_TOUCH, rx, ry, idx);
    } finally { L.fromStick = false; }
    // released sticks: the keyboard hides a cursor 100 ms after its last position
  };

  function enhance(popup) {
    const p = popup.m_popup;
    if (!p || p.closed) return false;
    const d = p.document;
    const inst = findInstance(d);
    if (!inst) return false;
    if (!inst.props || !inst.props.bStandalone) return true; // not the desktop standalone keyboard
    L.popup = popup;
    L.inst = inst;
    L.xkb = null;                                  // report the language on the first update
    L.pos = L.openPos || "bottom";                // set by L.open(); manual opens start at the bottom
    L.openPos = null;
    L.hideRequested = false;
    L.suppressLayoutOnce = false;
    patchPrototype(Object.getPrototypeOf(inst));
    guardResize(p);
    injectStyle(d);
    installLongPress(d);
    installPadInput();
    installTabKey(inst);
    patchLayout(inst);
    syncLang(inst);
    L.cleanups.push(releaseMods);
    try { inst.forceUpdate(); } catch (e) {} // re-render so VKMove secondary disappears
    scheduleFit();
    notify("shown");
    return true;
  }

  function waitAndEnhance(popup, tries = 0) {
    if (!L.enabled) return;
    try { if (enhance(popup)) return; }
    catch (e) { L.lastError = String(e && e.stack || e); log("enhance failed", e); return; }
    if (tries < 100) setTimeout(() => waitAndEnhance(popup, tries + 1), 30); // bounded: <= 3 s, only while opening
  }

  function onCreated(popup) {
    try { if (popup && isKbPopupName(popup.m_strName)) waitAndEnhance(popup); } catch (e) { log(e); }
  }
  function onDestroyed(popup) {
    try {
      if (!popup || !isKbPopupName(popup.m_strName)) return;
      if (L.popup !== popup) return;
      L.popup = null; L.inst = null;
      if (L.lpTimer) { clearTimeout(L.lpTimer); L.lpTimer = 0; }
      L.cleanups.splice(0).forEach((f) => { try { f(); } catch (e) {} });
      notify("hidden", { manual: true, hideKey: L.hideRequested });
      L.hideRequested = false;
    } catch (e) { log(e); }
  }

  // ---------------------------------------------------------------- API for the helper
  // caret = {top, bottom} in screen px (from lgk-helper) or null. The keyboard opens at the bottom
  // unless that would cover the caret / field and the top position would not.
  function posFor(caret, scr) {
    if (!caret) return "bottom";
    // screen geometry comes from KWin via the helper (Steam's hidden context reports a 1x1 screen)
    const s = scr || window.screen;
    const kbH = L.lastH || 348;
    const areaTop = caret.areaTop ?? (s.availTop || 0);
    const areaBottom = caret.areaBottom ?? (areaTop + (s.availHeight || s.height));
    const screenBottom = caret.screenBottom ?? s.height;
    const bottomEdge = areaBottom < screenBottom ? areaBottom : screenBottom;
    const coveredBottom = caret.bottom > bottomEdge - kbH - 4;
    const coveredTop = caret.top < areaTop + kbH + 4;
    if (coveredBottom && !coveredTop) return "top";
    if (coveredTop && !coveredBottom) return "bottom";
    return null;                                   // fits either way (or neither): no preference
  }
  L.avoid = (caret) => {
    if (!isOurs(L.inst)) return "closed";
    const p = L.popup.m_popup;
    const want = posFor(caret, p && p.screen);
    if (want && want !== L.pos) togglePosition();
    return L.pos;
  };
  L.open = (caret) => {
    if (!L.enabled) return "disabled";
    if (kbPopup()) { L.avoid(caret); return "already"; }
    L.openPos = posFor(caret) || "bottom";
    SteamClient.URL.ExecuteSteamURL("steam://open/keyboard");
    return "opening";
  };
  L.isOpen = () => !!kbPopup();
  L.status = () => JSON.stringify({ version: VERSION, lastError: L.lastError, open: !!kbPopup(), pos: L.pos, unsupported: L.unsupported, bridge: !!L.bridgeOn, pad: L.padStats });
  L.teardown = () => {
    L.enabled = false;
    if (L.proto) for (const [k, f] of Object.entries(L.originals)) L.proto[k] = f;
    try { releaseMods(); } catch (e) {}
    for (const [sl, f] of L.layoutPatches.splice(0)) sl.rgLayout = f;
    L.cleanups.splice(0).forEach((f) => { try { f(); } catch (e) {} });
    const pp = L.popup && L.popup.m_popup;
    if (pp && !pp.closed) {
      const d = pp.document;
      d.getElementById("lgk-style")?.remove();
      const th = d.querySelector("[data-lgk-ty]");
      if (th) { th.style.transform = ""; delete th.dataset.lgkTy; }
    }
    if (window[NS] === L) delete window[NS];
    return "lgk: removed (reopen keyboard for fully stock styling)";
  };

  // ---------------------------------------------------------------- install
  if (typeof g_PopupManager === "undefined" || !g_PopupManager.AddPopupCreatedCallback || !g_PopupManager.m_mapPopups) {
    L.unsupported.push("g_PopupManager");
    return "lgk: unsupported Steam build (no popup manager) — stock keyboard left untouched";
  }
  // callbacks cannot be unregistered: they check L.enabled / window[NS] identity
  g_PopupManager.AddPopupCreatedCallback((p) => { if (window[NS] === L) onCreated(p); });
  if (g_PopupManager.AddPopupDestroyedCallback)
    g_PopupManager.AddPopupDestroyedCallback((p) => { if (window[NS] === L) onDestroyed(p); });
  else L.unsupported.push("AddPopupDestroyedCallback");

  const existing = kbPopup();
  if (existing) waitAndEnhance(existing);
  return "lgk: installed v" + VERSION + (L.unsupported.length ? " (unsupported: " + L.unsupported.join(",") + ")" : "");
})();
