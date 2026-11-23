// lgk: report the active window's client geometry to lgk-helper (event driven, no polling).
// Loaded by lgk-helper at start, unloaded on exit. Only geometry is sent.
let cur = null;
function send() {
    if (!cur) return;
    const g = cur.clientGeometry;
    const a = workspace.clientArea(KWin.MaximizeArea, cur);      // usable area of its screen (no panels)
    const sc = workspace.clientArea(KWin.ScreenArea, cur);       // whole screen
    callDBus("org.legiondesktop.lgk", "/lgk", "org.legiondesktop.lgk", "ActiveWindow",
             [g.x, g.y, g.width, g.height, a.y, a.y + a.height, sc.y, sc.y + sc.height,
              String(cur.resourceClass || "").replace(/,/g, "")].join(","));
}
function track(w) {
    if (cur) { try { cur.clientGeometryChanged.disconnect(send); } catch (e) {} }
    cur = (w && !w.specialWindow && w.wantsInput) ? w : cur;
    if (cur === w && cur) cur.clientGeometryChanged.connect(send);
    send();
}
workspace.windowActivated.connect(track);
track(workspace.activeWindow);
