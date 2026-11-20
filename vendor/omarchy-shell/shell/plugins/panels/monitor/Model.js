function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue

    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))

    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

// tr is an optional translate(key, english) from the QML side (I18n.t);
// without it the English text stands, which is what the Node tests assert.
function brightnessName(percent, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var p = Math.round(percent)
  if (p >= 95) return t("monitor.level.sunBlast", "Sun blast")
  if (p >= 80) return t("monitor.level.solarFlare", "Solar flare")
  if (p >= 65) return t("monitor.level.goldenHour", "Golden hour")
  if (p >= 45) return t("monitor.level.evenDay", "Even day")
  if (p >= 30) return t("monitor.level.softGlow", "Soft glow")
  if (p >= 20) return t("monitor.level.lampLight", "Lamp light")
  if (p >= 10) return t("monitor.level.candlelit", "Candlelit")
  return t("monitor.level.nightOwl", "Night owl")
}

function parseDisplays(raw) {
  var displays = []
  try {
    displays = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    displays = []
  }
  if (!Array.isArray(displays)) displays = []

  var count = 0
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].enabled) count++
  }

  return {
    displays: displays,
    enabledDisplayCount: count
  }
}

// Pad the fractional part of a milli-Hz value to the three digits niri
// expects in a mode string ("120.000", "119.880").
function pad3(value) {
  var s = String(value)
  while (s.length < 3) s = "0" + s
  return s
}

function fixedHz(refreshRate) {
  var n = Number(refreshRate)
  if (!isFinite(n) || n <= 0) return ""
  var whole = Math.floor(n / 1000)
  var frac = Math.round(n - whole * 1000)
  if (frac >= 1000) { whole += 1; frac -= 1000 }
  return whole + "." + pad3(frac)
}

// Human-readable refresh rate without trailing zeros: 120000 -> "120",
// 119880 -> "119.88".
function shortHz(refreshRate) {
  var value = fixedHz(refreshRate)
  if (!value) return ""
  value = value.replace(/0+$/, "")
  value = value.replace(/\.$/, "")
  return value
}

// QML can hand nested JSON arrays back as QVariantList rather than a JS
// array. Accept both so the resolution picker works after a Repeater
// round-trip.
function asList(value) {
  if (!value) return []
  if (Array.isArray(value)) return value
  if (typeof value.length === "number") {
    var list = []
    for (var i = 0; i < value.length; i++) list.push(value[i])
    return list
  }
  return []
}

// Dropdown options for a display: one entry per resolution, using the
// highest refresh rate available for it. `display.resolutions` comes from
// omarchy-monitor-state.
function resolutionOptions(display) {
  var options = []
  if (!display) return options
  var resolutions = asList(display.resolutions)
  for (var i = 0; i < resolutions.length; i++) {
    var mode = resolutions[i]
    if (!mode || !mode.width || !mode.height) continue
    var value = mode.width + "x" + mode.height
    options.push({
      value: value,
      label: value + " · " + shortHz(mode.refresh_rate) + " Hz"
    })
  }
  return options
}

// Build the exact "WxH@R" argument for `niri msg output <name> mode`.
function modeString(display, resolution) {
  if (!display) return ""
  var resolutions = asList(display.resolutions)
  for (var i = 0; i < resolutions.length; i++) {
    var mode = resolutions[i]
    if (!mode) continue
    if ((mode.width + "x" + mode.height) !== resolution) continue
    return resolution + "@" + fixedHz(mode.refresh_rate)
  }
  return ""
}

if (typeof module !== "undefined") {
  module.exports = {
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    brightnessName: brightnessName,
    parseDisplays: parseDisplays,
    fixedHz: fixedHz,
    shortHz: shortHz,
    resolutionOptions: resolutionOptions,
    modeString: modeString
  }
}
