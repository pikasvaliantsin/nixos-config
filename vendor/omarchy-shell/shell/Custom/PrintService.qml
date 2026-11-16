pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One watched print folder. The helper `omarchy-print` owns the file list and
// the printed/not-printed state; this singleton only polls it, keeps the
// checkbox selection, and starts a batch. State belongs here rather than in
// the panel because the bar widget needs the unprinted count while the panel
// is closed and lazily built.
Singleton {
  id: root

  property var documents: []
  property string folder: ""
  property string printer: ""
  property bool loading: false
  property bool loaded: false
  property bool printing: false

  // Selection survives polls, but a document seen for the first time starts
  // selected when it has not been printed yet. That is what makes "Print new"
  // and "Print selected" agree right after files are dropped in.
  property var selected: ({})
  property var known: ({})

  property string printOutput: ""
  property string errorText: ""
  // Result of the last print action, kept until the next one. A list refresh
  // clears only `errorText`, so a successful batch still says what it did.
  property string message: ""
  property bool messageError: false

  readonly property int newCount: {
    var count = 0
    for (var i = 0; i < documents.length; i++) {
      if (!documents[i].printed) count++
    }
    return count
  }

  readonly property int selectedCount: {
    var count = 0
    for (var i = 0; i < documents.length; i++) {
      if (selected[documents[i].path]) count++
    }
    return count
  }

  function isSelected(path) {
    return !!root.selected[path]
  }

  function toggle(path) {
    var next = {}
    for (var key in root.selected) next[key] = root.selected[key]
    if (next[path]) delete next[path]
    else next[path] = true
    root.selected = next
  }

  function selectNew() {
    var next = {}
    for (var i = 0; i < root.documents.length; i++) {
      if (!root.documents[i].printed) next[root.documents[i].path] = true
    }
    root.selected = next
  }

  function clearSelection() {
    root.selected = ({})
  }

  function clearMessage() {
    root.message = ""
    root.messageError = false
  }

  function refresh() {
    if (listProc.running || printProc.running) return
    root.loading = true
    root.errorText = ""
    listProc.running = true
  }

  function parseList(raw) {
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (error) { parsed = null }
    if (!parsed || !Array.isArray(parsed.documents)) {
      root.loaded = true
      root.loading = false
      return
    }

    var docs = parsed.documents.slice()
    docs.sort(function(a, b) {
      return String(a.name || "").localeCompare(String(b.name || ""))
    })

    // A path that was not in the previous list is a new arrival. Printed
    // documents never auto-select; existing choices (including a printed
    // document picked for a reprint) are kept across polls.
    var nextSelected = {}
    var nextKnown = {}
    for (var i = 0; i < docs.length; i++) {
      var doc = docs[i]
      nextKnown[doc.path] = true
      if (root.selected[doc.path]) nextSelected[doc.path] = true
      else if (!root.known[doc.path] && !doc.printed) nextSelected[doc.path] = true
    }

    root.known = nextKnown
    root.selected = nextSelected
    root.documents = docs
    root.folder = String(parsed.folder || "")
    root.printer = String(parsed.printer || "")
    root.loaded = true
    root.loading = false
  }

  function selectedPaths() {
    var paths = []
    for (var i = 0; i < root.documents.length; i++) {
      var doc = root.documents[i]
      if (root.selected[doc.path]) paths.push(doc.path)
    }
    return paths
  }

  // systemd-run resolves the command without the shell wrapper's PATH, so an
  // absolute helper path is required. OMARCHY_PATH is set by that wrapper.
  function helperPath() {
    var omarchy = Quickshell.env("OMARCHY_PATH")
    return omarchy && omarchy !== "" ? omarchy + "/bin/omarchy-print" : "omarchy-print"
  }

  function runPrint(args) {
    if (root.printing) return
    root.printing = true
    root.printOutput = ""
    root.errorText = ""
    root.message = ""
    root.messageError = false
    root.selected = ({})
    printProc.command = [
      "systemd-run", "--user", "--scope", "--collect", "--quiet",
      "--slice=app.slice", "--", root.helperPath(), "print"
    ].concat(args)
    printProc.running = true
  }

  function lastLine(text) {
    var lines = String(text || "").trim().split("\n")
    while (lines.length > 0 && lines[lines.length - 1].trim() === "") lines.pop()
    return lines.length > 0 ? lines[lines.length - 1].trim() : ""
  }

  function printNew() {
    if (root.newCount === 0) return
    runPrint(["--new"])
  }

  function printSelected() {
    var paths = selectedPaths()
    if (paths.length === 0) return
    runPrint(["--"].concat(paths))
  }

  Process {
    id: listProc
    command: [root.helperPath(), "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseList(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.errorText = message
      }
    }
    onExited: function(code) {
      root.loading = false
      if (code !== 0 && root.errorText === "") {
        root.errorText = "omarchy-print list failed"
      }
    }
  }

  Process {
    id: printProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.printOutput = String(text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.errorText = String(text || "").trim()
    }
    onExited: function(code) {
      root.printing = false
      var outputLine = root.lastLine(root.printOutput)
      var errorLine = root.lastLine(root.errorText)
      if (code !== 0) {
        root.message = errorLine !== "" ? errorLine
          : (outputLine !== "" ? outputLine : "Printing failed")
        root.messageError = true
      } else {
        root.message = outputLine !== "" ? outputLine : "Done"
        root.messageError = false
      }
      Qt.callLater(function() { root.refresh() })
    }
  }

  Timer {
    interval: 20000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
