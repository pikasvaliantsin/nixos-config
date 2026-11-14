import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DevTools.js" as DevTools

// Developer toolbox overlay: generators and one-shot text transformers.
//
// The JS engine is pure and runs in-process. Inputs big enough that the QML
// engine would stutter are handed to the system tools instead: base64 above
// 32 KiB, JSON above 96 KiB, and diffs beyond 1500 lines go through
// base64(1), jq(1) and diff(1). Those paths write a temp file and never build
// a shell string.
Item {
  id: root

  property bool opened: false
  property string toolId: "uuid"
  property string query: ""
  property string inputText: ""
  property string originalText: ""
  property string modifiedText: ""
  property string outputText: ""
  property string errorText: ""
  property string noticeText: ""
  property bool copied: false
  property bool pendingGenerate: false
  property var options: ({})
  // "js" or "native" for the last completed run; used by the IPC checks.
  property string lastPath: ""

  readonly property string tmpDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-devtools"

  readonly property var tools: [
    {
      id: "uuid",
      name: "UUID",
      title: "UUID generator",
      description: "Random v4 identifiers, or v7 identifiers that sort by creation time.",
      kind: "generator",
      sample: "",
      options: [
        { id: "version", type: "choice", label: "Version", default: "4", choices: [
            { value: "4", label: "v4 · random" }, { value: "7", label: "v7 · time-ordered" } ] },
        { id: "quantity", type: "choice", label: "Count", default: "1", choices: [
            { value: "1", label: "1" }, { value: "5", label: "5" }, { value: "10", label: "10" } ] },
        { id: "uppercase", type: "toggle", label: "Uppercase", default: false },
        { id: "hyphens", type: "toggle", label: "Hyphens", default: true }
      ]
    },
    {
      id: "password",
      name: "Password",
      title: "Password generator",
      description: "Cryptographically random passwords from the character sets you pick.",
      kind: "generator",
      sample: "",
      options: [
        { id: "length", type: "choice", label: "Length", default: "20", choices: [
            { value: "12", label: "12" }, { value: "16", label: "16" }, { value: "20", label: "20" },
            { value: "32", label: "32" }, { value: "64", label: "64" } ] },
        { id: "quantity", type: "choice", label: "Count", default: "1", choices: [
            { value: "1", label: "1" }, { value: "5", label: "5" }, { value: "10", label: "10" } ] },
        { id: "uppercase", type: "toggle", label: "A-Z", default: true },
        { id: "lowercase", type: "toggle", label: "a-z", default: true },
        { id: "numbers", type: "toggle", label: "0-9", default: true },
        { id: "symbols", type: "toggle", label: "!@#$", default: true },
        { id: "avoidAmbiguous", type: "toggle", label: "Avoid l, 1, O, 0", default: true }
      ]
    },
    {
      id: "json",
      name: "JSON",
      title: "JSON formatter",
      description: "Format, minify, sort keys and validate JSON. Large documents go through jq.",
      kind: "transformer",
      multiline: true,
      sample: "{\"service\":\"orders\",\"port\":8080,\"features\":[\"json\",\"yaml\"],\"active\":true}",
      options: [
        { id: "indent", type: "choice", label: "Format", default: "2", choices: [
            { value: "2", label: "2 spaces" }, { value: "4", label: "4 spaces" },
            { value: "tab", label: "Tab" }, { value: "minified", label: "Minify" } ] },
        { id: "sortKeys", type: "toggle", label: "Sort keys", default: false }
      ]
    },
    {
      id: "base64",
      name: "Base64",
      title: "Base64 encode / decode",
      description: "UTF-8 text to Base64 and back, optionally URL-safe. Large payloads use base64(1).",
      kind: "transformer",
      multiline: true,
      sample: "Hello World! 🚀",
      options: [
        { id: "mode", type: "choice", label: "Mode", default: "encode", choices: [
            { value: "encode", label: "Encode" }, { value: "decode", label: "Decode" } ] },
        { id: "urlSafe", type: "toggle", label: "URL safe", default: false }
      ]
    },
    {
      id: "url",
      name: "URL",
      title: "URL encode / decode",
      description: "Escape a whole URL or a single path or query component.",
      kind: "transformer",
      multiline: true,
      sample: "https://example.com/search?query=hello world & cat=1",
      options: [
        { id: "mode", type: "choice", label: "Mode", default: "encode", choices: [
            { value: "encode", label: "Encode" }, { value: "decode", label: "Decode" } ] },
        { id: "component", type: "toggle", label: "One component", default: true }
      ]
    },
    {
      id: "jwt",
      name: "JWT",
      title: "JWT decoder",
      description: "Read a token's header, payload and time claims. The signature is not verified.",
      kind: "transformer",
      multiline: true,
      sample: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
      options: []
    },
    {
      id: "timestamp",
      name: "Timestamp",
      title: "Unix timestamp",
      description: "Convert epoch seconds or milliseconds to dates and back. Empty means now.",
      kind: "transformer",
      multiline: false,
      placeholder: "1700000000, 1700000000000 or 2026-11-14T12:00:00Z",
      sample: "1700000000",
      options: []
    },
    {
      id: "color",
      name: "Colour",
      title: "Colour converter",
      description: "Convert between hex, rgb() and hsl(), including alpha.",
      kind: "transformer",
      multiline: false,
      placeholder: "#8ec07c, rgb(142, 192, 124), hsl(103, 35%, 62%)",
      sample: "#8ec07c",
      options: []
    },
    {
      id: "regex",
      name: "Regex",
      title: "Regex tester",
      description: "Run a JavaScript regular expression and inspect every match and group.",
      kind: "transformer",
      multiline: true,
      sample: "order 4711 for alice@example.com, order 4712 for bob@example.org",
      options: [
        { id: "pattern", type: "text", label: "Pattern", default: "([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})" },
        { id: "flags", type: "text", label: "Flags", default: "g" }
      ]
    },
    {
      id: "diff",
      name: "Diff",
      title: "Text diff",
      description: "Compare two texts line by line. Beyond 1500 lines it switches to diff(1).",
      kind: "diff",
      options: []
    },
    {
      id: "chmod",
      name: "chmod",
      title: "chmod calculator",
      description: "Translate permissions between octal and symbolic forms, including special bits.",
      kind: "transformer",
      multiline: false,
      placeholder: "755 or rwxr-xr-x",
      sample: "755",
      options: []
    }
  ]

  readonly property var currentTool: {
    for (var index = 0; index < tools.length; index++)
      if (tools[index].id === toolId) return tools[index]
    return tools[0]
  }

  readonly property var filteredTools: {
    var needle = query.trim().toLowerCase()
    if (needle.length === 0) return tools
    return tools.filter(function(tool) {
      return (tool.name + " " + tool.title + " " + tool.description).toLowerCase().indexOf(needle) >= 0
    })
  }

  // Text options (the regex pattern and flags) are drawn above the input rather
  // than in the pill rows.
  readonly property var choiceOptions: {
    var definitions = currentTool.options ? currentTool.options : []
    var visible = []
    for (var index = 0; index < definitions.length; index++)
      if (definitions[index].type === "choice") visible.push(definitions[index])
    return visible
  }

  readonly property var toggleOptions: {
    var definitions = currentTool.options ? currentTool.options : []
    var visible = []
    for (var index = 0; index < definitions.length; index++)
      if (definitions[index].type === "toggle") visible.push(definitions[index])
    return visible
  }

  readonly property var textOptions: {
    var definitions = currentTool.options ? currentTool.options : []
    var visible = []
    for (var index = 0; index < definitions.length; index++)
      if (definitions[index].type === "text") visible.push(definitions[index])
    return visible
  }

  readonly property bool needsInput: currentTool.kind !== "generator" && currentTool.kind !== "diff"
  readonly property bool isDiff: currentTool.kind === "diff"

  readonly property int cardWidth: Math.min(Style.space(880), Math.max(Style.space(560), panel.width - Style.gapsOut * 4))
  readonly property int cardHeight: Math.min(Style.space(620), Math.max(Style.space(420), panel.height - Style.gapsOut * 6))

  // ---------------------------------------------------------------- lifecycle

  function open() {
    if (root.opened) return
    root.opened = true
    root.query = ""
    root.selectTool(root.toolId)
    Qt.callLater(function() {
      if (root.needsInput && inputArea) inputArea.forceInputFocus()
      else if (searchField) searchField.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function defaultsFor(tool) {
    var defaults = {}
    var definitions = tool && tool.options ? tool.options : []
    for (var index = 0; index < definitions.length; index++) {
      var definition = definitions[index]
      defaults[definition.id] = definition.default
    }
    return defaults
  }

  function selectTool(id) {
    var tool = null
    for (var index = 0; index < root.tools.length; index++)
      if (root.tools[index].id === id) tool = root.tools[index]
    if (!tool) tool = root.tools[0]
    root.toolId = tool.id
    root.options = root.defaultsFor(tool)
    root.outputText = ""
    root.errorText = ""
    root.noticeText = ""
    root.copied = false
    root.pendingGenerate = false
    if (tool.kind === "diff") {
      root.originalText = "first line\nsecond line\nthird line"
      root.modifiedText = "first line\nsecond line changed\nthird line"
      root.inputText = ""
    } else {
      root.inputText = tool.sample !== undefined ? tool.sample : ""
      root.originalText = ""
      root.modifiedText = ""
    }
    inputArea.setText(root.inputText)
    originalArea.setText(root.originalText)
    modifiedArea.setText(root.modifiedText)
    root.runNow()
  }

  function setOption(id, value) {
    var next = {}
    for (var key in root.options) next[key] = root.options[key]
    next[id] = value
    root.options = next
    root.runNow()
  }

  function updateInput(value) {
    root.inputText = value
    if (root.needsInput) debounce.restart()
  }

  function updateOriginal(value) {
    root.originalText = value
    if (root.isDiff) debounce.restart()
  }

  function updateModified(value) {
    root.modifiedText = value
    if (root.isDiff) debounce.restart()
  }

  function selectRelative(step) {
    var list = root.filteredTools
    if (list.length === 0) return
    var position = 0
    for (var index = 0; index < list.length; index++)
      if (list[index].id === root.toolId) position = index
    root.selectTool(list[(position + step + list.length) % list.length].id)
  }

  // ------------------------------------------------------------ random source

  property var randomPool: ({ bytes: [], index: 0 })

  function nextRandomByte() {
    if (!root.randomPool.bytes || root.randomPool.index >= root.randomPool.bytes.length)
      throw new Error("Secure random source unavailable")
    var value = root.randomPool.bytes[root.randomPool.index]
    root.randomPool.index = root.randomPool.index + 1
    if (root.randomPool.bytes.length - root.randomPool.index < 16384 && !randomProc.running)
      randomProc.running = true
    return value
  }

  function randomSource() {
    return { byte: root.nextRandomByte }
  }

  Process {
    id: randomProc
    command: ["od", "-An", "-v", "-t", "u1", "-N", "32768", "/dev/urandom"]
    stdout: StdioCollector {
      onStreamFinished: {
        var cleaned = text.trim()
        if (cleaned.length === 0) return
        var tokens = cleaned.split(/\s+/)
        var bytes = []
        for (var index = 0; index < tokens.length; index++) {
          var value = Number(tokens[index])
          if (!Number.isInteger(value) || value < 0 || value > 255) return
          bytes.push(value)
        }
        if (bytes.length !== 32768) return
        root.randomPool = { bytes: bytes, index: 0 }
        if (root.pendingGenerate) {
          root.pendingGenerate = false
          root.noticeText = ""
          root.runNow()
        }
      }
    }
  }

  // ---------------------------------------------------------------- execution

  function lineCount(value) {
    return String(value).split(/\r?\n/).length
  }

  function needsNative(tool) {
    if (tool.id === "base64") return root.inputText.length > 32768
    if (tool.id === "json") return root.inputText.length > 98304
    if (tool.kind === "diff")
      return root.lineCount(root.originalText) > 1500 || root.lineCount(root.modifiedText) > 1500
    return false
  }

  function apply(value) {
    root.errorText = value && value.error ? String(value.error) : ""
    root.outputText = value && value.output ? String(value.output) : ""
    root.copied = false
  }

  function runNow() {
    var tool = root.currentTool
    if (!tool) return
    root.errorText = ""
    root.noticeText = ""
    root.copied = false

    if (tool.kind === "generator") {
      if (root.randomPool.bytes.length === 0) {
        root.pendingGenerate = true
        root.noticeText = "Preparing secure random source…"
        if (!randomProc.running) randomProc.running = true
        return
      }
      root.lastPath = "js"
      root.apply(DevTools.run(tool.id, "", root.options, root.randomSource()))
      return
    }

    if (root.needsNative(tool)) {
      root.runNative(tool)
      return
    }

    var effectiveOptions = root.options
    if (tool.kind === "diff") {
      effectiveOptions = {}
      for (var key in root.options) effectiveOptions[key] = root.options[key]
      effectiveOptions.original = root.originalText
      effectiveOptions.modified = root.modifiedText
    }
    root.lastPath = "js"
    root.apply(DevTools.run(tool.id, root.inputText, effectiveOptions, root.randomSource()))
  }

  property string nativeKind: ""
  property string loadMode: "input"
  property bool nativeExitSeen: false
  property bool nativeStreamSeen: false
  property int nativeExitCode: 0

  function runNative(tool) {
    root.nativeKind = tool.id
    root.lastPath = "native"
    root.errorText = ""
    root.outputText = ""
    root.noticeText = "Large input: using " + (tool.id === "json" ? "jq" : (tool.id === "base64" ? "base64" : "diff")) + "…"
    root.nativeExitSeen = false
    root.nativeStreamSeen = false

    if (tool.id === "diff") {
      inputFile.setText(root.originalText)
      otherFile.setText(root.modifiedText)
      nativeProc.command = ["diff", "-u", "--label", "Original", "--label", "Modified",
                            inputFile.path, otherFile.path]
    } else if (tool.id === "base64") {
      inputFile.setText(root.inputText)
      nativeProc.command = root.options.mode === "decode"
        ? ["base64", "-d", inputFile.path]
        : ["base64", "-w0", inputFile.path]
    } else {
      inputFile.setText(root.inputText)
      var command = ["jq"]
      if (root.options.sortKeys) command.push("-S")
      if (root.options.indent === "minified") command.push("-c")
      else if (root.options.indent === "tab") command.push("--tab")
      else command.push("--indent", root.options.indent === "4" ? "4" : "2")
      command.push(".")
      command.push(inputFile.path)
      nativeProc.command = command
    }
    nativeProc.running = true
  }

  function maybeFinishNative() {
    if (!root.nativeExitSeen || !root.nativeStreamSeen) return
    root.nativeExitSeen = false
    root.nativeStreamSeen = false
    root.finishNative(root.nativeExitCode)
  }

  function finishNative(exitCode) {
    var kind = root.nativeKind
    var stdoutText = String(nativeOut.text)
    var stderrText = String(nativeErr.text)
    root.noticeText = ""

    if (kind === "diff") {
      if (exitCode === 0) root.apply({ output: "No differences", error: "" })
      else if (exitCode === 1) root.apply({ output: stdoutText.replace(/\n+$/, ""), error: "" })
      else root.apply({ output: "", error: stderrText.trim() || "diff failed" })
      return
    }
    if (exitCode !== 0) {
      root.apply({ output: "", error: stderrText.trim() || "Command failed" })
      return
    }
    root.apply({ output: stdoutText.replace(/\n+$/, ""), error: "" })
  }

  function copyOutput() {
    if (root.outputText.length === 0) return
    // Mark generated passwords with the standard x-kde-passwordManagerHint so
    // the clipboard history watcher skips them (capture.sh checks that type).
    var command = ["wl-copy"]
    if (root.toolId === "password") command.push("--sensitive")
    command.push(root.outputText)
    Quickshell.execDetached(command)
    root.copied = true
    copiedTimer.restart()
  }

  function clearOutput() {
    root.outputText = ""
    root.errorText = ""
    root.noticeText = ""
    root.copied = false
  }

  Timer {
    id: debounce
    interval: 260
    onTriggered: root.runNow()
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copied = false
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.tmpDir]
    running: true
  }

  FileView {
    id: inputFile
    path: root.tmpDir + "/input.txt"
    blockWrites: true
    printErrors: false
  }

  FileView {
    id: otherFile
    path: root.tmpDir + "/modified.txt"
    blockWrites: true
    printErrors: false
  }

  // Reads a file into the current tool. Used by `omarchy-ipc call devtools
  // load <path>` so the panel works from a terminal with real payloads.
  FileView {
    id: loader
    printErrors: false
    onLoaded: {
      var content = text()
      if (root.loadMode === "original") {
        root.originalText = content
        originalArea.setText(content)
      } else if (root.loadMode === "modified") {
        root.modifiedText = content
        modifiedArea.setText(content)
      } else {
        root.inputText = content
        inputArea.setText(content)
      }
      root.runNow()
    }
    onLoadFailed: root.apply({ output: "", error: "Cannot read " + path })
  }

  Process {
    id: nativeProc
    stdout: StdioCollector {
      id: nativeOut
      onStreamFinished: {
        root.nativeStreamSeen = true
        root.maybeFinishNative()
      }
    }
    stderr: StdioCollector { id: nativeErr }
    onExited: function(exitCode, exitStatus) {
      root.nativeExitCode = exitCode
      root.nativeExitSeen = true
      root.maybeFinishNative()
    }
  }

  ShellIpc {
    target: "devtools"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function tool(name: string): void { root.selectTool(name) }
    function input(text: string): void {
      root.inputText = text
      inputArea.setText(text)
      root.runNow()
    }
    function option(id: string, value: string): void {
      var normalized = value
      if (value === "true") normalized = true
      else if (value === "false") normalized = false
      root.setOption(id, normalized)
    }
    function copy(): void { root.copyOutput() }
    function compare(original: string, modified: string): void {
      root.originalText = original
      root.modifiedText = modified
      originalArea.setText(original)
      modifiedArea.setText(modified)
      root.runNow()
    }
    function load(path: string): void {
      root.loadMode = "input"
      loader.path = path
      loader.reload()
    }
    function loadOriginal(path: string): void {
      root.loadMode = "original"
      loader.path = path
      loader.reload()
    }
    function loadModified(path: string): void {
      root.loadMode = "modified"
      loader.path = path
      loader.reload()
    }
    function output(): string { return root.outputText }
    function outputSize(): string { return String(root.outputText.length) }
    function outputStart(): string { return root.outputText.slice(0, 200) }
    function path(): string { return root.lastPath }
    function lastError(): string { return root.errorText }
    function notice(): string { return root.noticeText }
  }

  Shortcut {
    sequence: "Escape"
    enabled: root.opened
    onActivated: root.close()
  }

  Shortcut {
    sequence: "Ctrl+Return"
    enabled: root.opened
    onActivated: root.runNow()
  }

  Component.onCompleted: {
    root.options = root.defaultsFor(root.currentTool)
    randomProc.running = true
  }

  // ---------------------------------------------------------------------- UI

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-devtools"

    onShownChanged: if (shown) Qt.callLater(function() {
      if (root.needsInput && inputArea) inputArea.forceInputFocus()
      else if (searchField) searchField.forceActiveFocus()
    })

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: Style.space(16)

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(12)

        // Header ----------------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: "Developer tools"
            color: Commons.Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Item { Layout.fillWidth: true }

          TextField {
            id: searchField
            Layout.preferredWidth: Style.space(190)
            placeholderText: "Search tools"
            foreground: Commons.Color.menu.text
            accent: Commons.Color.accent
            Keys.onDownPressed: root.selectRelative(1)
            Keys.onUpPressed: root.selectRelative(-1)
            Keys.onEscapePressed: root.close()
            onTextChanged: root.query = text
          }

          Text {
            text: "Esc"
            color: Commons.Color.menu.text
            opacity: 0.4
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Commons.Color.menu.border
          opacity: 0.35
        }

        // Body ------------------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(14)

          Column {
            Layout.preferredWidth: Style.space(164)
            Layout.fillHeight: true
            spacing: Style.space(2)

            Repeater {
              model: root.filteredTools
              delegate: Button {
                required property var modelData
                width: parent.width
                leftAlign: true
                text: modelData.name
                selected: root.toolId === modelData.id
                fontSize: Style.font.body
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(7)
                onClicked: root.selectTool(modelData.id)
              }
            }
          }

          Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Commons.Color.menu.border
            opacity: 0.35
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.space(8)

            Text {
              Layout.fillWidth: true
              text: root.currentTool.title
              color: Commons.Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: root.currentTool.description
              color: Commons.Color.menu.text
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            // Choice rows --------------------------------------------------
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)
              visible: root.choiceOptions.length > 0

              Repeater {
                model: root.choiceOptions
                delegate: Item {
                  id: choiceRow
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: choiceLayout.implicitHeight

                  RowLayout {
                    id: choiceLayout
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      Layout.preferredWidth: Style.space(86)
                      text: choiceRow.modelData.label
                      color: Commons.Color.menu.text
                      opacity: 0.5
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    Row {
                      spacing: Style.space(2)

                      Repeater {
                        model: choiceRow.modelData.choices
                        delegate: Button {
                          required property var modelData
                          text: String(modelData.label)
                          selected: String(root.options[choiceRow.modelData.id]) === String(modelData.value)
                          fontSize: Style.font.caption
                          horizontalPadding: Style.space(8)
                          verticalPadding: Style.space(4)
                          onClicked: root.setOption(choiceRow.modelData.id, modelData.value)
                        }
                      }
                    }
                    Item { Layout.fillWidth: true }
                  }
                }
              }
            }

            // Toggle pills -------------------------------------------------
            Flow {
              Layout.fillWidth: true
              spacing: Style.space(6)
              visible: root.toggleOptions.length > 0

              Repeater {
                model: root.toggleOptions
                delegate: Row {
                  required property var modelData
                  spacing: Style.space(4)

                  Text {
                    text: modelData.label
                    color: Commons.Color.menu.text
                    opacity: 0.5
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Button {
                    text: root.options[modelData.id] ? "On" : "Off"
                    selected: Boolean(root.options[modelData.id])
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(8)
                    verticalPadding: Style.space(4)
                    onClicked: root.setOption(modelData.id, !root.options[modelData.id])
                  }
                }
              }
            }

            // Text options (regex pattern and flags) ----------------------
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)
              visible: root.textOptions.length > 0

              Repeater {
                model: root.textOptions
                delegate: RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Text {
                    text: modelData.label
                    color: Commons.Color.menu.text
                    opacity: 0.5
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                  TextField {
                    Layout.fillWidth: true
                    text: String(root.options[modelData.id] !== undefined ? root.options[modelData.id] : "")
                    foreground: Commons.Color.menu.text
                    accent: Commons.Color.accent
                    onTextChanged: root.setOption(modelData.id, text)
                  }
                }
              }
            }

            // Input -------------------------------------------------------
            Text {
              Layout.fillWidth: true
              visible: root.needsInput
              text: "Input"
              color: Commons.Color.menu.text
              opacity: 0.45
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            CodeArea {
              id: inputArea
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(122)
              visible: root.needsInput
              placeholder: root.currentTool.placeholder ? root.currentTool.placeholder : "Paste or type here"
              wrap: !root.currentTool.multiline
              onEdited: function(value) { root.updateInput(value) }
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              visible: root.isDiff
              spacing: Style.space(8)

              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.space(4)

                Text {
                  text: "Original"
                  color: Commons.Color.menu.text
                  opacity: 0.45
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                CodeArea {
                  id: originalArea
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  placeholder: "Original"
                  onEdited: function(value) { root.updateOriginal(value) }
                }
              }
              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.space(4)

                Text {
                  text: "Modified"
                  color: Commons.Color.menu.text
                  opacity: 0.45
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                CodeArea {
                  id: modifiedArea
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  placeholder: "Modified"
                  onEdited: function(value) { root.updateModified(value) }
                }
              }
            }

            // Output ------------------------------------------------------
            Text {
              Layout.fillWidth: true
              text: "Result"
              color: Commons.Color.menu.text
              opacity: 0.45
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            CodeArea {
              Layout.fillWidth: true
              Layout.fillHeight: true
              readOnly: true
              placeholder: "Result"
              text: root.outputText
            }

            // Footer ------------------------------------------------------
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              Text {
                Layout.fillWidth: true
                text: root.errorText.length > 0 ? root.errorText
                      : (root.noticeText.length > 0 ? root.noticeText
                      : (root.copied ? "Copied to clipboard" : "Ctrl+Enter runs · Esc closes"))
                color: root.errorText.length > 0 ? Commons.Color.urgent : Commons.Color.menu.text
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Button {
                text: root.currentTool.kind === "generator" ? "Generate" : "Run"
                fontSize: Style.font.bodySmall
                onClicked: root.runNow()
              }
              Button {
                text: "Copy"
                fontSize: Style.font.bodySmall
                selected: root.copied
                onClicked: root.copyOutput()
              }
              Button {
                text: "Clear"
                fontSize: Style.font.bodySmall
                onClicked: root.clearOutput()
              }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------ widgets

  component CodeArea: Rectangle {
    id: area

    property alias text: editor.text
    property alias placeholder: editor.placeholderText
    property alias readOnly: editor.readOnly
    property bool wrap: false
    property bool settingText: false
    signal edited(string value)

    color: "transparent"
    radius: Style.space(5)
    border.width: 1
    border.color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g,
                          Commons.Color.menu.border.b, 0.35)

    function setText(value) {
      area.settingText = true
      editor.text = value
      area.settingText = false
    }

    function forceInputFocus() {
      editor.forceActiveFocus()
    }

    QQC.ScrollView {
      anchors.fill: parent
      anchors.margins: Style.space(6)
      clip: true
      QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded
      QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AsNeeded

      QQC.TextArea {
        id: editor
        wrapMode: area.wrap ? TextEdit.WrapAnywhere : TextEdit.NoWrap
        color: Commons.Color.menu.text
        selectionColor: Style.selectionFillFor(Commons.Color.menu.text, Commons.Color.accent)
        selectedTextColor: Commons.Color.menu.text
        placeholderTextColor: Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g,
                                      Commons.Color.menu.text.b, 0.35)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        selectByMouse: true
        background: null
        padding: 0
        onTextChanged: {
          if (!area.settingText) area.edited(editor.text)
        }
      }
    }
  }
}
