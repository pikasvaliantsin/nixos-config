import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "AppSearch.js" as AppSearch

// Shared desktop-application library: the sorted entry list with hidden-entry
// filtering, the icon fallback index, launch feedback, and entry removal.
// Injected as shell.appLibrary; the menu's Apps submenu is the consumer.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  property var configuredHiddenEntryIds: ({})
  property var desktopHiddenEntryIds: ({})

  // User-owned launcher state. The shipped launcher.hides in the package is
  // read-only, so runtime hide/pin choices live under the user's config.
  readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string userHidesPath: root.configDir + "/omarchy/launcher.hides"
  readonly property string pinsPath: root.configDir + "/omarchy/launcher.pins"
  property var userHiddenEntryIds: ({})
  property var pinnedEntryIds: []
  property var pinnedRank: ({})

  // Maps an icon name to a file on disk (e.g. "omacut" -> ".../apps/omacut.svg").
  // Used as a fallback for icons that Qt's themed lookup misses because they were
  // installed after this process started (its icon cache never re-scans). Refreshed
  // whenever the app list changes, so newly installed apps get their icon live.
  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  property int launchSerial: 0
  property int launchToplevelCount: 0
  property var launchActiveToplevel: null
  // True while the launch OSD is on screen. It outlives the launch that opened
  // it: the OSD shows with duration 0, so only closeLaunchFeedback() takes it
  // down.
  property bool launchOsdOpen: false
  property string launchOsdMessage: ""

  // Emitted whenever the visible application set may have changed: desktop
  // entries appeared or vanished, or the hidden-entry filters reloaded.
  signal appsChanged()

  function entryName(entry) {
    return AppSearch.entryName(entry)
  }

  function entrySubtext(entry) {
    return AppSearch.entrySubtext(entry)
  }

  function isHiddenEntry(entry) {
    var id = root.normalizeDesktopId(entry && entry.id)
    return root.configuredHiddenEntryIds[id] === true
      || root.userHiddenEntryIds[id] === true
      || root.desktopHiddenEntryIds[id] === true
  }

  function isPinnedEntry(entry) {
    return root.pinnedRank[root.normalizeDesktopId(entry && entry.id)] !== undefined
  }

  function pinnedRankOf(entry) {
    var rank = root.pinnedRank[root.normalizeDesktopId(entry && entry.id)]
    return rank === undefined ? -1 : rank
  }

  // The shipped hides file is a config file, not a data file: blank lines and
  // comments are ignored, and order only matters for pins.
  function parseIdLines(rawText) {
    var ids = []
    var seen = ({})
    var lines = String(rawText || "").split(/\n/)
    for (var i = 0; i < lines.length; i++) {
      var line = String(lines[i] || "").trim()
      if (!line || line.charAt(0) === "#") continue
      var id = root.normalizeDesktopId(line)
      if (!id || seen[id]) continue
      seen[id] = true
      ids.push(id)
    }
    return ids
  }

  function idLines(ids) {
    return ids.length > 0 ? ids.join("\n") + "\n" : ""
  }

  function loadUserHides(rawText) {
    var ids = root.parseIdLines(rawText)
    var next = ({})
    for (var i = 0; i < ids.length; i++) next[ids[i]] = true
    root.userHiddenEntryIds = next
    root.appsChanged()
  }

  function loadPins(rawText) {
    root.setPinned(root.parseIdLines(rawText), false)
    root.appsChanged()
  }

  function setPinned(ids, emit) {
    var next = []
    var seen = ({})
    for (var i = 0; i < ids.length; i++) {
      var id = root.normalizeDesktopId(ids[i])
      if (!id || seen[id]) continue
      seen[id] = true
      next.push(id)
    }
    var ranks = ({})
    for (var j = 0; j < next.length; j++) ranks[next[j]] = j
    root.pinnedEntryIds = next
    root.pinnedRank = ranks
    if (emit !== false) root.appsChanged()
  }

  function savePins() {
    pinsFile.setText(root.idLines(root.pinnedEntryIds))
  }

  function saveUserHides() {
    userHidesFile.setText(root.idLines(Object.keys(root.userHiddenEntryIds).sort()))
  }

  function togglePin(desktopId) {
    var id = root.normalizeDesktopId(desktopId)
    if (!id) return
    var ids = root.pinnedEntryIds.slice()
    var index = ids.indexOf(id)
    if (index >= 0) ids.splice(index, 1)
    else ids.push(id)
    root.setPinned(ids, true)
    root.savePins()
  }

  function movePin(desktopId, delta) {
    var id = root.normalizeDesktopId(desktopId)
    var ids = root.pinnedEntryIds.slice()
    var from = ids.indexOf(id)
    if (from < 0) return
    var to = Math.max(0, Math.min(ids.length - 1, from + delta))
    if (to === from) return
    ids.splice(from, 1)
    ids.splice(to, 0, id)
    root.setPinned(ids, true)
    root.savePins()
  }

  function hideEntry(desktopId) {
    var id = root.normalizeDesktopId(desktopId)
    if (!id) return
    var next = ({})
    var ids = Object.keys(root.userHiddenEntryIds)
    if (ids.indexOf(id) < 0) ids.push(id)
    for (var i = 0; i < ids.length; i++) next[ids[i]] = true
    root.userHiddenEntryIds = next
    root.saveUserHides()
    if (root.pinnedRank[id] !== undefined) {
      root.setPinned(root.pinnedEntryIds.filter(function(value) { return value !== id }), false)
      root.savePins()
    }
    root.appsChanged()
  }

  function unhideEntry(desktopId) {
    var id = root.normalizeDesktopId(desktopId)
    if (root.userHiddenEntryIds[id] !== true) return
    var next = ({})
    var ids = Object.keys(root.userHiddenEntryIds)
    for (var i = 0; i < ids.length; i++) if (ids[i] !== id) next[ids[i]] = true
    root.userHiddenEntryIds = next
    root.saveUserHides()
    root.appsChanged()
  }

  // Only entries hidden by the user can be restored here. NoDisplay entries
  // and the shipped launcher.hides are intentionally absent: writing to the
  // user file would not override them.
  function hiddenEntries() {
    var values = DesktopEntries.applications.values || []
    var rows = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay) continue
      var id = root.normalizeDesktopId(entry.id)
      if (!id || root.userHiddenEntryIds[id] !== true) continue
      rows.push(entry)
    }
    rows.sort(function(a, b) {
      var aName = root.entryName(a).toLowerCase()
      var bName = root.entryName(b).toLowerCase()
      if (aName < bName) return -1
      if (aName > bName) return 1
      return 0
    })
    return rows
  }

  function sortedEntries(query) {
    var values = DesktopEntries.applications.values || []
    return AppSearch.sortedEntries(values, query, function(entry) { return root.isHiddenEntry(entry) })
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    // Prefer the context-limited app/device index. An unconstrained themed
    // lookup can resolve an app name such as "zoom" to an action icon instead.
    var found = root.iconIndex[value]
    if (found) return Util.fileUrl(found)
    var themed = Quickshell.iconPath(value, true)
    if (themed.length > 0) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  // The shell may start before first-install packages have finished placing
  // their icons; consumers call this when they open so icons appear live.
  function refreshIcons() {
    if (!iconIndexScan.running) iconIndexScan.running = true
  }

  function launch(desktopId, name) {
    var id = String(desktopId || "")
    if (!id) return
    root.beginLaunchFeedback(name)
    // NixOS/niri does not run a UWSM session, so upstream's
    // `uwsm-app -- gtk-launch` and `omarchy-launch-tui` are not available.
    // TUI entries run in foot; GUI entries use gtk-launch, which resolves the
    // desktop id through the XDG data dirs and honours DBus activation.
    var command = root.terminalCommand(DesktopEntries.byId(id))
    if (command.length > 0) {
      Util.execArgv(["foot", "-e"].concat(command))
      return
    }
    // Keep the .desktop suffix or ids like org.telegram.desktop won't resolve.
    Util.execDetached("gtk-launch " + Util.shellQuote(id + ".desktop"))
  }

  // The command a terminal entry runs, without the field codes it leaves for a
  // launcher to fill in; empty for an entry that is not run in a terminal.
  function terminalCommand(entry) {
    if (!entry || !entry.runInTerminal) return []
    return (entry.command || []).filter(function(word) { return !/^%[a-zA-Z]$/.test(String(word)) })
  }

  function remove(desktopId, name) {
    var id = String(desktopId || "")
    if (!id) return
    Util.execDetached(Util.shellQuote(root.omarchyPath + "/bin/omarchy-remove-launcher-entry") + " " + Util.shellQuote(id) + " " + Util.shellQuote(String(name || id)))
  }

  function normalizeDesktopId(id) {
    var value = String(id || "").trim()
    if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
    return value
  }

  function loadConfiguredHides(rawText) {
    var next = ({})
    var lines = String(rawText || "").split(/\n/)
    for (var i = 0; i < lines.length; i++) {
      var id = root.normalizeDesktopId(lines[i])
      if (id.length > 0) next[id] = true
    }
    root.configuredHiddenEntryIds = next
    root.appsChanged()
  }

  function loadDesktopHiddenEntries(rawText) {
    var next = ({})
    var lines = String(rawText || "").split(/\n/)
    for (var i = 0; i < lines.length; i++) {
      var id = root.normalizeDesktopId(lines[i])
      if (id.length > 0) next[id] = true
    }
    root.desktopHiddenEntryIds = next
    root.appsChanged()
  }

  function iconIndexScanCommand() {
    // List app/device icons across the XDG icon dirs and /usr/share/pixmaps as
    // "<path>" lines. Some desktop entries, such as Print Settings, use device
    // icons like "printer" instead of app icons. SVGs are emitted before PNGs
    // so the parser, which keeps the first hit per name, prefers scalable icons.
    return [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      '{',
      '  for base in $dirs; do',
      '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null;',
      '  done;',
      '  find /usr/share/pixmaps -maxdepth 1 \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null;',
      '} | awk \'/\\.svg$/ { print; next } { png[++n] = $0 } END { for (i = 1; i <= n; i++) print png[i] }\''
    ].join(' ')
  }

  function indexIconLine(path) {
    var value = String(path || "").trim()
    if (value.length === 0) return
    var slash = value.lastIndexOf("/")
    var file = slash >= 0 ? value.slice(slash + 1) : value
    var dot = file.lastIndexOf(".")
    var name = dot > 0 ? file.slice(0, dot) : file
    if (name.length > 0 && root.pendingIconIndex[name] === undefined)
      root.pendingIconIndex[name] = value
  }

  function hiddenEntryScanCommand() {
    var desktop = [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")].filter(function(v) { return String(v || "").length > 0 }).join(":")
    var script = root.omarchyPath + "/shell/services/hidden-entries.sh"
    return Util.shellQuote(script) + " " + Util.shellQuote(desktop)
  }

  function toplevelCount() {
    try { return ToplevelManager.toplevels.values.length } catch (e) { return 0 }
  }

  function beginLaunchFeedback(name) {
    root.launchSerial++
    root.launchToplevelCount = root.toplevelCount()
    root.launchActiveToplevel = ToplevelManager.activeToplevel
    root.launchOsdMessage = name ? I18n.t("appLibrary.launching").arg(String(name)) : I18n.t("appLibrary.launchingApp")
    launchDelay.restart()
    launchTimeout.restart()
  }

  function closeLaunchFeedback(serial) {
    if (serial !== root.launchSerial) return
    launchDelay.stop()
    launchTimeout.stop()
    if (root.launchOsdOpen) {
      Quickshell.execDetached(["omarchy-shell", "osd", "close"])
      root.launchOsdOpen = false
    }
  }

  function maybeFinishLaunchFeedback() {
    if (!launchDelay.running && !launchTimeout.running && !root.launchOsdOpen) return
    if (root.toplevelCount() <= root.launchToplevelCount && ToplevelManager.activeToplevel === root.launchActiveToplevel) return
    root.closeLaunchFeedback(root.launchSerial)
  }

  QtObject {
    id: hiddenEntryOutput
    property string text: ""
  }

  // Both scans must run in non-login shells. A login shell sources the user's
  // profile, and tools like mise touch ~/.local/share on activation — a
  // directory the desktop-entry watcher monitors — so every scan would
  // trigger the next one, pinning a core at idle.
  Process {
    id: hiddenEntryScan
    command: ["bash", "-c", root.hiddenEntryScanCommand()]
    stdout: SplitParser { onRead: function(line) { hiddenEntryOutput.text += line + "\n" } }
    onStarted: hiddenEntryOutput.text = ""
    onExited: root.loadDesktopHiddenEntries(hiddenEntryOutput.text)
  }

  Process {
    id: iconIndexScan
    command: ["bash", "-c", root.iconIndexScanCommand()]
    stdout: SplitParser { onRead: function(line) { root.indexIconLine(line) } }
    onStarted: root.pendingIconIndex = ({})
    // Swapping the property re-evaluates every iconSource() binding, so
    // newly found icons appear without rebuilding the list.
    onExited: root.iconIndex = root.pendingIconIndex
  }

  // Coalesces bursts of app-list changes (a package install touches many
  // entries) into a single rescan.
  Timer {
    id: iconIndexDebounce
    interval: 750
    onTriggered: if (!iconIndexScan.running) iconIndexScan.running = true
  }

  FileView {
    path: root.omarchyPath + "/default/omarchy/launcher.hides"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadConfiguredHides(text())
    onFileChanged: root.loadConfiguredHides(text())
    onLoadFailed: root.loadConfiguredHides("")
  }

  FileView {
    id: userHidesFile
    path: root.userHidesPath
    watchChanges: true
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onLoaded: root.loadUserHides(text())
    onLoadFailed: root.loadUserHides("")
    onFileChanged: reload()
  }

  FileView {
    id: pinsFile
    path: root.pinsPath
    watchChanges: true
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onLoaded: root.loadPins(text())
    onLoadFailed: root.loadPins("")
    onFileChanged: reload()
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.maybeFinishLaunchFeedback() }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.maybeFinishLaunchFeedback() }
  }

  Timer {
    id: launchDelay
    interval: 2000
    onTriggered: {
      if (root.toplevelCount() > root.launchToplevelCount || ToplevelManager.activeToplevel !== root.launchActiveToplevel) return
      root.launchOsdOpen = true
      Quickshell.execDetached(["omarchy-shell", "osd", "show", JSON.stringify({ icon: "󱓞", message: root.launchOsdMessage, duration: 0 })])
    }
  }

  Timer {
    id: launchTimeout
    interval: 15000
    onTriggered: root.closeLaunchFeedback(root.launchSerial)
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      hiddenEntryScan.running = true
      iconIndexDebounce.restart()
      root.appsChanged()
    }
  }

  Component.onCompleted: {
    hiddenEntryScan.running = true
    iconIndexScan.running = true
  }
}
