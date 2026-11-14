.pragma library

// DevTools engine: pure functions only. No IO, no timers, no QML objects.
// The panel supplies the secure random source for the generators; every other
// tool is deterministic and safe to call on each keystroke.
//
// Every tool returns { output: string, error: string }. Errors are shown as-is,
// so messages stay short and printable.

var BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
var BASE64_LOOKUP = (function() {
  var table = []
  for (var index = 0; index < 256; index++) table.push(-1)
  for (var charIndex = 0; charIndex < BASE64_ALPHABET.length; charIndex++)
    table[BASE64_ALPHABET.charCodeAt(charIndex)] = charIndex
  table["-".charCodeAt(0)] = 62
  table["_".charCodeAt(0)] = 63
  return table
})()

// ---------------------------------------------------------------------------
// UTF-8 and Base64

function utf8Encode(text) {
  if (typeof TextEncoder !== "undefined") return new TextEncoder().encode(text)
  var bytes = []
  for (var index = 0; index < text.length; index++) {
    var code = text.charCodeAt(index)
    if (code >= 0xd800 && code < 0xdc00 && index + 1 < text.length) {
      var low = text.charCodeAt(index + 1)
      if (low >= 0xdc00 && low < 0xe000) {
        code = 0x10000 + (((code & 0x3ff) << 10) | (low & 0x3ff))
        index++
      }
    }
    if (code < 0x80) {
      bytes.push(code)
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f))
    } else if (code < 0x10000) {
      bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
    } else {
      bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f),
                 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
    }
  }
  return bytes
}

function utf8Decode(bytes) {
  if (typeof TextDecoder !== "undefined") return new TextDecoder().decode(new Uint8Array(bytes))
  var output = ""
  var index = 0
  while (index < bytes.length) {
    var first = bytes[index++]
    if (first < 0x80) {
      output += String.fromCharCode(first)
    } else if (first < 0xc0) {
      output += "\ufffd"
    } else if (first < 0xe0) {
      var second = bytes[index++] || 0
      output += String.fromCharCode(((first & 0x1f) << 6) | (second & 0x3f))
    } else if (first < 0xf0) {
      // Each branch reads its own continuation bytes. Reusing `second` here
      // would pull the byte from a previous iteration (or undefined).
      var secondThree = bytes[index++] || 0
      var thirdThree = bytes[index++] || 0
      output += String.fromCharCode(((first & 0x0f) << 12)
        | ((secondThree & 0x3f) << 6) | (thirdThree & 0x3f))
    } else {
      var secondFour = bytes[index++] || 0
      var thirdFour = bytes[index++] || 0
      var fourthFour = bytes[index++] || 0
      var point = (((first & 0x07) << 18) | ((secondFour & 0x3f) << 12)
                   | ((thirdFour & 0x3f) << 6) | (fourthFour & 0x3f)) - 0x10000
      output += String.fromCharCode(0xd800 + (point >> 10), 0xdc00 + (point & 0x3ff))
    }
  }
  return output
}

function encodeBase64(bytes, urlSafe) {
  var output = []
  for (var index = 0; index < bytes.length; index += 3) {
    var first = bytes[index]
    var second = index + 1 < bytes.length ? bytes[index + 1] : 0
    var third = index + 2 < bytes.length ? bytes[index + 2] : 0
    var combined = (first << 16) | (second << 8) | third
    output.push(BASE64_ALPHABET[(combined >> 18) & 0x3f])
    output.push(BASE64_ALPHABET[(combined >> 12) & 0x3f])
    output.push(index + 1 < bytes.length ? BASE64_ALPHABET[(combined >> 6) & 0x3f] : "=")
    output.push(index + 2 < bytes.length ? BASE64_ALPHABET[combined & 0x3f] : "=")
  }
  var text = output.join("")
  if (!urlSafe) return text
  return text.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function decodeBase64(value, urlSafe) {
  var text = String(value).replace(/\s+/g, "")
  if (text.length === 0) return []
  if (!/^[A-Za-z0-9+/\-_]*={0,2}$/.test(text))
    throw new Error("Not a Base64 value (bad characters or misplaced padding)")
  if (text.length % 4 === 1) throw new Error("Base64 length is invalid")
  while (text.length % 4 !== 0) text += "="
  var bytes = []
  for (var index = 0; index < text.length; index += 4) {
    var chunk = text.slice(index, index + 4)
    var values = []
    for (var offset = 0; offset < 4; offset++) {
      var char = chunk[offset]
      if (char === "=") {
        values.push(0)
        continue
      }
      var mapped = BASE64_LOOKUP[char.charCodeAt(0)]
      if (mapped === undefined || mapped < 0) throw new Error("Invalid Base64 character: " + char)
      values.push(mapped)
    }
    var combined = (values[0] << 18) | (values[1] << 12) | (values[2] << 6) | values[3]
    bytes.push((combined >> 16) & 0xff)
    if (chunk[2] !== "=") bytes.push((combined >> 8) & 0xff)
    if (chunk[3] !== "=") bytes.push(combined & 0xff)
  }
  return bytes
}

// ---------------------------------------------------------------------------
// Secure random helpers. The pool is owned by the panel so a keystroke never
// waits for /dev/urandom.

function randomByte(random) {
  if (!random || typeof random.byte !== "function")
    throw new Error("Secure random source unavailable")
  var value = Number(random.byte())
  if (!Number.isInteger(value) || value < 0 || value > 255)
    throw new Error("Secure random source returned invalid data")
  return value
}

function randomBelow(random, maximum) {
  var max = Number(maximum)
  if (!Number.isInteger(max) || max < 1 || max > 256) throw new Error("Invalid random range")
  var limit = 256 - (256 % max)
  var value
  do {
    value = randomByte(random)
  } while (value >= limit)
  return value % max
}

// ---------------------------------------------------------------------------
// Generators

function makePassword(random, options) {
  var opts = options || {}
  var length = Math.max(4, Math.min(128, Number(opts.length) || 20))
  var quantity = Math.max(1, Math.min(50, Number(opts.quantity) || 1))

  var upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  var lower = "abcdefghijklmnopqrstuvwxyz"
  var digits = "0123456789"
  var symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
  if (opts.avoidAmbiguous !== false) {
    upper = upper.replace(/[IO]/g, "")
    lower = lower.replace(/[lo]/g, "")
    digits = digits.replace(/[01]/g, "")
    symbols = symbols.replace(/[|`'"]/g, "")
  }

  var alphabets = []
  if (opts.uppercase !== false) alphabets.push(upper)
  if (opts.lowercase !== false) alphabets.push(lower)
  if (opts.numbers !== false) alphabets.push(digits)
  if (opts.symbols !== false) alphabets.push(symbols)
  if (alphabets.length === 0) alphabets.push(lower)

  var pool = alphabets.join("")
  var passwords = []
  for (var item = 0; item < quantity; item++) {
    var characters = []
    for (var alphabetIndex = 0; alphabetIndex < alphabets.length; alphabetIndex++) {
      var alphabet = alphabets[alphabetIndex]
      characters.push(alphabet[randomBelow(random, alphabet.length)])
    }
    while (characters.length < length)
      characters.push(pool[randomBelow(random, pool.length)])
    for (var index = characters.length - 1; index > 0; index--) {
      var swap = randomBelow(random, index + 1)
      var value = characters[index]
      characters[index] = characters[swap]
      characters[swap] = value
    }
    passwords.push(characters.join(""))
  }
  return { output: passwords.join("\n"), error: "" }
}

function uuidFromBytes(bytes, uppercase, hyphens) {
  var hex = []
  for (var index = 0; index < 16; index++)
    hex.push((bytes[index] < 16 ? "0" : "") + bytes[index].toString(16))
  var text = hex.join("")
  if (hyphens)
    text = text.slice(0, 8) + "-" + text.slice(8, 12) + "-" + text.slice(12, 16) + "-"
           + text.slice(16, 20) + "-" + text.slice(20)
  return uppercase ? text.toUpperCase() : text
}

function makeUuid(random, options) {
  var opts = options || {}
  var version = String(opts.version || "4") === "7" ? 7 : 4
  var uppercase = Boolean(opts.uppercase)
  var hyphens = opts.hyphens !== false
  var quantity = Math.max(1, Math.min(50, Number(opts.quantity) || 1))
  var uuids = []
  for (var item = 0; item < quantity; item++) {
    var bytes = []
    for (var index = 0; index < 16; index++) bytes.push(randomByte(random))
    if (version === 7) {
      var timestamp = Date.now()
      bytes[0] = Math.floor(timestamp / 0x10000000000) & 0xff
      bytes[1] = Math.floor(timestamp / 0x100000000) & 0xff
      bytes[2] = Math.floor(timestamp / 0x1000000) & 0xff
      bytes[3] = Math.floor(timestamp / 0x10000) & 0xff
      bytes[4] = Math.floor(timestamp / 0x100) & 0xff
      bytes[5] = timestamp & 0xff
    }
    bytes[6] = (bytes[6] & 0x0f) | (version === 7 ? 0x70 : 0x40)
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    uuids.push(uuidFromBytes(bytes, uppercase, hyphens))
  }
  return { output: uuids.join("\n"), error: "" }
}

// ---------------------------------------------------------------------------
// Text transformers

function sortKeysDeep(value) {
  if (Array.isArray(value)) return value.map(sortKeysDeep)
  if (value && typeof value === "object") {
    var sorted = {}
    Object.keys(value).sort().forEach(function(key) {
      sorted[key] = sortKeysDeep(value[key])
    })
    return sorted
  }
  return value
}

function formatJson(input, options) {
  var opts = options || {}
  var text = String(input).replace(/^\uFEFF/, "").trim()
  if (text.length === 0) return { output: "", error: "" }
  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (error) {
    return { output: "", error: String(error.message || error) }
  }
  if (opts.sortKeys) parsed = sortKeysDeep(parsed)
  var minified = opts.indent === "minified"
  var indent = minified ? "" : (opts.indent === "4" ? "    " : (opts.indent === "tab" ? "\t" : "  "))
  return { output: JSON.stringify(parsed, null, indent), error: "" }
}

function encodeText(input, options) {
  var opts = options || {}
  var text = String(input)
  if (opts.mode === "decode") {
    try {
      var bytes = decodeBase64(text, Boolean(opts.urlSafe))
      return { output: utf8Decode(bytes), error: "" }
    } catch (error) {
      return { output: "", error: String(error.message || error) }
    }
  }
  return { output: encodeBase64(utf8Encode(text), Boolean(opts.urlSafe)), error: "" }
}

function encodeUrl(input, options) {
  var opts = options || {}
  var text = String(input)
  if (text.length === 0) return { output: "", error: "" }
  try {
    if (opts.mode === "decode")
      return { output: opts.component ? decodeURIComponent(text) : decodeURI(text), error: "" }
    return { output: opts.component ? encodeURIComponent(text) : encodeURI(text), error: "" }
  } catch (error) {
    return { output: "", error: "Malformed URL escape sequence" }
  }
}

function decodeJwt(input) {
  var token = String(input).trim().replace(/^Bearer\s+/i, "")
  if (token.length === 0) return { output: "", error: "" }
  var parts = token.split(".")
  if (parts.length < 2 || parts.length > 3)
    return { output: "", error: "A JWT needs two or three dot-separated parts" }

  function decodePart(label, value) {
    try {
      var text = utf8Decode(decodeBase64(value, true))
      return JSON.stringify(JSON.parse(text), null, 2)
    } catch (error) {
      throw new Error(label + " is not valid Base64 JSON")
    }
  }

  var header, payload
  try {
    header = decodePart("Header", parts[0])
    payload = decodePart("Payload", parts[1])
  } catch (error) {
    return { output: "", error: String(error.message || error) }
  }

  var lines = ["HEADER", header, "", "PAYLOAD", payload]
  var claims = {}
  try {
    claims = JSON.parse(payload)
  } catch (error) {
    claims = {}
  }
  var claimLines = []
  var claimNames = ["iat", "nbf", "exp"]
  for (var index = 0; index < claimNames.length; index++) {
    var name = claimNames[index]
    var value = Number(claims[name])
    if (!Number.isFinite(value) || value <= 0) continue
    if (isNaN(new Date(value * 1000).getTime())) continue
    claimLines.push("  " + name + "  " + isoUtc(new Date(value * 1000))
                    + "  (" + describeWhen(value * 1000) + ")")
  }
  if (claimLines.length > 0) lines.push("", "TIME CLAIMS", claimLines.join("\n"))
  lines.push("", "Signature is shown but not verified.")
  return { output: lines.join("\n"), error: "" }
}

function padNumber(value, width) {
  var text = String(Math.abs(Math.trunc(value)))
  while (text.length < width) text = "0" + text
  return (value < 0 ? "-" : "") + text
}

function isoUtc(date) {
  return padNumber(date.getUTCFullYear(), 4) + "-" + padNumber(date.getUTCMonth() + 1, 2)
         + "-" + padNumber(date.getUTCDate(), 2) + "T" + padNumber(date.getUTCHours(), 2)
         + ":" + padNumber(date.getUTCMinutes(), 2) + ":" + padNumber(date.getUTCSeconds(), 2)
         + "." + padNumber(date.getUTCMilliseconds(), 3) + "Z"
}

function isoLocal(date) {
  var offset = -date.getTimezoneOffset()
  var sign = offset >= 0 ? "+" : "-"
  var hours = Math.floor(Math.abs(offset) / 60)
  var minutes = Math.abs(offset) % 60
  return padNumber(date.getFullYear(), 4) + "-" + padNumber(date.getMonth() + 1, 2)
         + "-" + padNumber(date.getDate(), 2) + "T" + padNumber(date.getHours(), 2)
         + ":" + padNumber(date.getMinutes(), 2) + ":" + padNumber(date.getSeconds(), 2)
         + "." + padNumber(date.getMilliseconds(), 3) + sign
         + padNumber(hours, 2) + ":" + padNumber(minutes, 2)
}

function describeWhen(milliseconds) {
  var delta = milliseconds - Date.now()
  var future = delta > 0
  var seconds = Math.round(Math.abs(delta) / 1000)
  var text
  if (seconds < 60) text = seconds + " s"
  else if (seconds < 3600) text = Math.round(seconds / 60) + " min"
  else if (seconds < 86400) text = Math.round(seconds / 3600) + " h"
  else text = Math.round(seconds / 86400) + " d"
  return future ? "in " + text : text + " ago"
}

function convertTimestamp(input) {
  var text = String(input).trim()
  var date
  if (text.length === 0) {
    date = new Date()
  } else if (/^-?\d+(\.\d+)?$/.test(text)) {
    var value = Number(text)
    var absolute = Math.abs(value)
    var milliseconds
    if (absolute < 1e11) milliseconds = value * 1000
    else if (absolute < 1e14) milliseconds = value
    else if (absolute < 1e17) milliseconds = value / 1000
    else milliseconds = value / 1e6
    date = new Date(milliseconds)
  } else {
    date = new Date(text)
  }
  if (isNaN(date.getTime())) return { output: "", error: "Not a timestamp or a date" }
  var seconds = Math.floor(date.getTime() / 1000)
  return {
    output: [
      "Epoch seconds  " + seconds,
      "Epoch millis   " + date.getTime(),
      "ISO UTC        " + isoUtc(date),
      "ISO local      " + isoLocal(date),
      "Relative       " + describeWhen(date.getTime())
    ].join("\n"),
    error: ""
  }
}

// ---------------------------------------------------------------------------
// Colour conversion

function clamp(value, low, high) {
  return Math.min(high, Math.max(low, value))
}

function parseColor(input) {
  var text = String(input || "").trim().toLowerCase()
  var hex = text.match(/^#?([0-9a-f]{3,8})$/)
  if (hex) {
    var value = hex[1]
    if (value.length !== 3 && value.length !== 4 && value.length !== 6 && value.length !== 8)
      throw new Error("Hex colours have 3, 4, 6 or 8 digits")
    if (value.length === 3 || value.length === 4)
      value = value.split("").map(function(char) { return char + char }).join("")
    var red = parseInt(value.slice(0, 2), 16)
    var green = parseInt(value.slice(2, 4), 16)
    var blue = parseInt(value.slice(4, 6), 16)
    var alpha = value.length >= 8 ? parseInt(value.slice(6, 8), 16) / 255 : 1
    if (!Number.isFinite(red) || !Number.isFinite(green) || !Number.isFinite(blue))
      throw new Error("Colour channels must be numbers")
    return { r: red, g: green, b: blue, a: alpha }
  }
  var rgb = text.match(/^rgba?\(([^)]+)\)$/)
  if (rgb) {
    var rgbParts = rgb[1].split(/[,/]/).map(function(part) { return part.trim() })
    if (rgbParts.length < 3) throw new Error("rgb() needs three channels")
    var channel = function(part) {
      if (part.slice(-1) === "%") return Math.round(parseFloat(part) * 2.55)
      return Math.round(parseFloat(part))
    }
    var alphaPart = rgbParts.length > 3 ? rgbParts[3] : "1"
    if (!Number.isFinite(parseFloat(rgbParts[0])) || !Number.isFinite(parseFloat(rgbParts[1]))
        || !Number.isFinite(parseFloat(rgbParts[2])) || !Number.isFinite(parseFloat(alphaPart)))
      throw new Error("Colour channels must be numbers")
    return {
      r: clamp(channel(rgbParts[0]), 0, 255),
      g: clamp(channel(rgbParts[1]), 0, 255),
      b: clamp(channel(rgbParts[2]), 0, 255),
      a: clamp(alphaPart.slice(-1) === "%" ? parseFloat(alphaPart) / 100 : parseFloat(alphaPart), 0, 1)
    }
  }
  var hsl = text.match(/^hsla?\(([^)]+)\)$/)
  if (hsl) {
    var parts = hsl[1].split(/[,/]/).map(function(part) { return part.trim() })
    if (parts.length < 3) throw new Error("hsl() needs three channels")
    if (!Number.isFinite(parseFloat(parts[0])) || !Number.isFinite(parseFloat(parts[1]))
        || !Number.isFinite(parseFloat(parts[2])))
      throw new Error("Colour channels must be numbers")
    var hue = ((parseFloat(parts[0]) % 360) + 360) % 360 / 360
    var saturation = clamp(parseFloat(parts[1]) / 100, 0, 1)
    var lightness = clamp(parseFloat(parts[2]) / 100, 0, 1)
    var alphaValue = parts.length > 3
      ? clamp(parts[3].slice(-1) === "%" ? parseFloat(parts[3]) / 100 : parseFloat(parts[3]), 0, 1)
      : 1
    var converted = hslToRgb(hue, saturation, lightness)
    converted.a = alphaValue
    return converted
  }
  throw new Error("Use hex, rgb(), rgba(), hsl() or hsla()")
}

function hslToRgb(hue, saturation, lightness) {
  if (saturation === 0) {
    var gray = Math.round(lightness * 255)
    return { r: gray, g: gray, b: gray }
  }
  var q = lightness < 0.5
    ? lightness * (1 + saturation)
    : lightness + saturation - lightness * saturation
  var p = 2 * lightness - q
  function channel(t) {
    if (t < 0) t += 1
    if (t > 1) t -= 1
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  return {
    r: Math.round(channel(hue + 1 / 3) * 255),
    g: Math.round(channel(hue) * 255),
    b: Math.round(channel(hue - 1 / 3) * 255)
  }
}

function rgbToHsl(color) {
  var red = color.r / 255
  var green = color.g / 255
  var blue = color.b / 255
  var max = Math.max(red, green, blue)
  var min = Math.min(red, green, blue)
  var lightness = (max + min) / 2
  var delta = max - min
  if (delta === 0) return { h: 0, s: 0, l: lightness }
  var saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min)
  var hue
  if (max === red) hue = ((green - blue) / delta + (green < blue ? 6 : 0)) / 6
  else if (max === green) hue = ((blue - red) / delta + 2) / 6
  else hue = ((red - green) / delta + 4) / 6
  return { h: hue * 360, s: saturation, l: lightness }
}

function hex2(value) {
  var text = Math.round(clamp(value, 0, 255)).toString(16)
  return text.length < 2 ? "0" + text : text
}

function convertColor(input) {
  var text = String(input || "").trim()
  if (text.length === 0) return { output: "", error: "" }
  var color
  try {
    color = parseColor(text)
  } catch (error) {
    return { output: "", error: String(error.message || error) }
  }
  var hsl = rgbToHsl(color)
  var alpha = color.a === undefined ? 1 : color.a
  var hex = "#" + hex2(color.r) + hex2(color.g) + hex2(color.b)
  if (alpha < 1) hex += hex2(alpha * 255)
  return {
    output: [
      "HEX  " + hex,
      "RGB  rgb(" + color.r + ", " + color.g + ", " + color.b + ")",
      "RGBA rgba(" + color.r + ", " + color.g + ", " + color.b + ", " + alpha.toFixed(2) + ")",
      "HSL  hsl(" + Math.round(hsl.h) + ", " + Math.round(hsl.s * 100) + "%, "
        + Math.round(hsl.l * 100) + "%)"
    ].join("\n"),
    error: ""
  }
}

// ---------------------------------------------------------------------------
// Regex

function testRegex(input, options) {
  var opts = options || {}
  var pattern = String(opts.pattern || "")
  var flags = String(opts.flags || "g")
  var text = String(input)
  if (pattern.length === 0) return { output: "", error: "" }
  // QV4's RegExp backtracks without a time limit: a catastrophic pattern can
  // otherwise block the whole shell. Keep both sides small.
  if (pattern.length > 1000) return { output: "", error: "Pattern is longer than 1000 characters" }
  if (text.length > 262144) return { output: "", error: "Text is longer than 256 KiB; use grep for that" }
  var expression
  try {
    expression = new RegExp(pattern, flags.indexOf("g") >= 0 ? flags : flags + "g")
  } catch (error) {
    return { output: "", error: String(error.message || error) }
  }
  if (text.length === 0) return { output: "", error: "Paste the text to match" }
  var lines = []
  var match
  var count = 0
  while ((match = expression.exec(text)) !== null && count < 200) {
    count++
    var groups = []
    for (var index = 1; index < match.length; index++)
      groups.push("    group " + index + ": " + (match[index] === undefined ? "—" : match[index]))
    lines.push((count + ".").padEnd(4) + "[" + match.index + ".." + (match.index + match[0].length)
               + "] " + (match[0].length > 200 ? match[0].slice(0, 200) + "…" : match[0]))
    if (groups.length > 0) lines.push(groups.join("\n"))
    if (match[0].length === 0) expression.lastIndex++
  }
  if (count === 0) return { output: "No match", error: "" }
  return { output: count + (count === 1 ? " match" : " matches") + "\n\n" + lines.join("\n"), error: "" }
}

// ---------------------------------------------------------------------------
// Text diff

var DIFF_MAX_LINES = 1500

function textDiff(original, modified) {
  var originalLines = String(original).split(/\r?\n/)
  var modifiedLines = String(modified).split(/\r?\n/)
  if (originalLines.length > DIFF_MAX_LINES || modifiedLines.length > DIFF_MAX_LINES)
    return { output: "", error: "Too large for the built-in diff (limit " + DIFF_MAX_LINES + " lines)" }

  var originalCount = originalLines.length
  var modifiedCount = modifiedLines.length
  var matrix = []
  for (var row = 0; row <= originalCount; row++) matrix.push(new Int32Array(modifiedCount + 1))
  for (var original = 0; original < originalCount; original++) {
    for (var modified = 0; modified < modifiedCount; modified++) {
      matrix[original + 1][modified + 1] = originalLines[original] === modifiedLines[modified]
        ? matrix[original][modified] + 1
        : Math.max(matrix[original + 1][modified], matrix[original][modified + 1])
    }
  }

  var cursorOriginal = originalCount
  var cursorModified = modifiedCount
  var additions = 0
  var deletions = 0
  var lines = []
  while (cursorOriginal > 0 || cursorModified > 0) {
    if (cursorOriginal > 0 && cursorModified > 0
        && originalLines[cursorOriginal - 1] === modifiedLines[cursorModified - 1]) {
      lines.push("  " + originalLines[cursorOriginal - 1])
      cursorOriginal--
      cursorModified--
    } else if (cursorModified > 0 && (cursorOriginal === 0
               || matrix[cursorOriginal][cursorModified - 1] >= matrix[cursorOriginal - 1][cursorModified])) {
      lines.push("+ " + modifiedLines[cursorModified - 1])
      additions++
      cursorModified--
    } else {
      lines.push("- " + originalLines[cursorOriginal - 1])
      deletions++
      cursorOriginal--
    }
  }
  lines.reverse()
  return {
    output: ["--- Original (" + originalCount + " lines)", "+++ Modified (" + modifiedCount + " lines)",
             "@@ -" + deletions + " +" + additions + " @@", lines.join("\n")].join("\n"),
    error: ""
  }
}

// ---------------------------------------------------------------------------
// chmod

var PERMISSION_BITS = ["read", "write", "execute"]

// Three permission pages plus the special digit. setuid/setgid/sticky are
// rendered back into the symbolic form (s/S/t/T), not just named.

function chmodPages(digits, special) {
  var pages = []
  for (var index = 0; index < 3; index++) {
    var digit = digits[index]
    var execute = "-"
    if (index === 0 && (special & 4)) execute = (digit & 1) ? "s" : "S"
    else if (index === 1 && (special & 2)) execute = (digit & 1) ? "s" : "S"
    else if (index === 2 && (special & 1)) execute = (digit & 1) ? "t" : "T"
    else if (digit & 1) execute = "x"
    pages.push((digit & 4 ? "r" : "-") + (digit & 2 ? "w" : "-") + execute)
  }
  return pages
}

function describeChmod(input) {
  var text = String(input || "").trim()
  if (text.length === 0) return { output: "", error: "" }
  var octalMatch = text.match(/^0?([0-7]{3,4})$/)
  var symbolicMatch = text.match(/^([-dlbcps])?([rwxstST-]{9})$/)
  var digits = [0, 0, 0]
  var special = 0

  if (octalMatch) {
    var octal = octalMatch[1]
    if (octal.length === 3) octal = "0" + octal
    special = Number(octal[0])
    for (var index = 0; index < 3; index++) digits[index] = Number(octal[index + 1])
  } else if (symbolicMatch) {
    var rights = symbolicMatch[2]
    for (var page = 0; page < 3; page++) {
      var chunk = rights.slice(page * 3, page * 3 + 3)
      var digit = 0
      if (chunk[0] === "r") digit += 4
      if (chunk[1] === "w") digit += 2
      var execute = chunk[2]
      if (execute === "x" || execute === "s" || execute === "t") digit += 1
      if (page === 0 && (execute === "s" || execute === "S")) special += 4
      if (page === 1 && (execute === "s" || execute === "S")) special += 2
      if (page === 2 && (execute === "t" || execute === "T")) special += 1
      digits[page] = digit
    }
  } else {
    return { output: "", error: "Use three or four octal digits, or rwxr-xr-x" }
  }

  var pages = chmodPages(digits, special)
  var specialNames = []
  if (special & 4) specialNames.push("setuid")
  if (special & 2) specialNames.push("setgid")
  if (special & 1) specialNames.push("sticky")
  var owners = ["Owner", "Group", "Other"]
  var lines = ["Octal     " + special + digits.join(""), "Symbolic  " + pages.join("")]
  for (var owner = 0; owner < 3; owner++) {
    var chunk = pages[owner]
    var names = []
    for (var bit = 0; bit < 3; bit++)
      if (chunk[bit] !== "-") names.push(PERMISSION_BITS[bit])
    lines.push(owners[owner].padEnd(10) + chunk + "  (" + (names.length ? names.join(", ") : "none") + ")")
  }
  lines.push("Special   " + (specialNames.length ? specialNames.join(", ") : "none"))
  return { output: lines.join("\n"), error: "" }
}

// ---------------------------------------------------------------------------
// Dispatcher

function run(toolId, input, options, random) {
  var opts = options || {}
  try {
    switch (toolId) {
    case "password":
      return makePassword(random, opts)
    case "uuid":
      return makeUuid(random, opts)
    case "json":
      return formatJson(input, opts)
    case "base64":
      return encodeText(input, opts)
    case "url":
      return encodeUrl(input, opts)
    case "jwt":
      return decodeJwt(input)
    case "timestamp":
      return convertTimestamp(input)
    case "color":
      return convertColor(input)
    case "regex":
      return testRegex(input, opts)
    case "diff":
      return textDiff(opts.original || "", opts.modified || "")
    case "chmod":
      return describeChmod(input)
    default:
      return { output: "", error: "Unknown tool: " + toolId }
    }
  } catch (error) {
    return { output: "", error: String(error && error.message ? error.message : error) }
  }
}

// The Node test harness uses this; QML ignores it.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    utf8Encode: utf8Encode,
    utf8Decode: utf8Decode,
    encodeBase64: encodeBase64,
    decodeBase64: decodeBase64,
    makePassword: makePassword,
    makeUuid: makeUuid,
    formatJson: formatJson,
    encodeText: encodeText,
    encodeUrl: encodeUrl,
    decodeJwt: decodeJwt,
    convertTimestamp: convertTimestamp,
    convertColor: convertColor,
    testRegex: testRegex,
    textDiff: textDiff,
    describeChmod: describeChmod,
    run: run
  }
}
