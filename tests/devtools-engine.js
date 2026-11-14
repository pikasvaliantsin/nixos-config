// Run with: nix shell nixpkgs#nodejs -c node tests/devtools-engine.js
const fs = require("fs")
const os = require("os")
const path = require("path")

const repo = path.resolve(__dirname, "..")
const engine = path.join(repo, "vendor/omarchy-shell/shell/Custom/DevTools.js")
const source = fs.readFileSync(engine, "utf8").replace(/^\.pragma library\n/, "")
const temp = path.join(os.tmpdir(), "devtools-engine.test.cjs")
fs.writeFileSync(temp, source)
const D = require(temp)

let failures = 0
function check(name, condition, detail) {
  if (!condition) {
    failures++
    console.log("FAIL " + name + (detail === undefined ? "" : " :: " + JSON.stringify(detail)))
  }
}
function eq(name, actual, expected) {
  check(name, actual === expected, { actual, expected })
}

// --- random source -------------------------------------------------------
let seed = 123456789
const rng = { byte: () => (seed = (seed * 1103515245 + 12345) % 2147483648) % 256 }

// --- base64 --------------------------------------------------------------
const sample = "Hello World! 🚀"
const encoded = D.encodeText(sample, { mode: "encode" }).output
eq("base64 encode", encoded, Buffer.from(sample, "utf8").toString("base64"))
eq("base64 decode", D.encodeText(encoded, { mode: "decode" }).output, sample)
const urlSafe = D.encodeText("??>>??", { mode: "encode", urlSafe: true }).output
check("base64 urlSafe alphabet", !/[+/=]/.test(urlSafe), urlSafe)
eq("base64 urlSafe roundtrip", D.encodeText(urlSafe, { mode: "decode", urlSafe: true }).output, "??>>??")
check("base64 invalid", D.encodeText("!!!!", { mode: "decode" }).error.length > 0)

// --- uuid ----------------------------------------------------------------
const v4 = D.makeUuid(rng, { version: "4" }).output
check("uuid v4 shape", /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(v4), v4)
const v7 = D.makeUuid(rng, { version: "7" }).output
check("uuid v7 shape", /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(v7), v7)
const v7ms = parseInt(v7.replace(/-/g, "").slice(0, 12), 16)
check("uuid v7 timestamp", Math.abs(v7ms - Date.now()) < 5000, { v7ms, now: Date.now() })
const noHyphens = D.makeUuid(rng, { version: "4", hyphens: false, uppercase: true }).output
check("uuid plain upper", /^[0-9A-F]{32}$/.test(noHyphens), noHyphens)
eq("uuid quantity", D.makeUuid(rng, { version: "4", quantity: 5 }).output.split("\n").length, 5)
check("uuid unique", new Set(D.makeUuid(rng, { version: "4", quantity: 50 }).output.split("\n")).size === 50)

// --- password ------------------------------------------------------------
const pw = D.makePassword(rng, { length: 20 }).output
eq("password length", pw.length, 20)
check("password classes", /[A-Z]/.test(pw) && /[a-z]/.test(pw) && /[0-9]/.test(pw) && /[^A-Za-z0-9]/.test(pw), pw)
check("password avoids ambiguous", !/[IlO01|`'"]/.test(D.makePassword(rng, { length: 40, quantity: 20 }).output))
eq("password quantity", D.makePassword(rng, { length: 12, quantity: 3 }).output.split("\n").length, 3)

// --- json ----------------------------------------------------------------
const json = '{"b":1,"a":[1,2,{"z":true,"y":null}]}'
const pretty = D.formatJson(json, { indent: "2" }).output
check("json indent 2", pretty.includes('\n  "b": 1'), pretty)
eq("json minified", D.formatJson(json, { indent: "minified" }).output, '{"b":1,"a":[1,2,{"z":true,"y":null}]}')
const sorted = D.formatJson(json, { indent: "minified", sortKeys: true }).output
check("json sorted", sorted.indexOf('"a"') < sorted.indexOf('"b"'), sorted)
check("json error", D.formatJson("{oops", {}).error.length > 0)
eq("json empty", D.formatJson("   ", {}).output, "")

// --- url -----------------------------------------------------------------
eq("url component", D.encodeUrl("a b&c=d", { mode: "encode", component: true }).output, "a%20b%26c%3Dd")
eq("url full", D.encodeUrl("https://x.test/a b?c=d&e=f", { mode: "encode", component: false }).output, "https://x.test/a%20b?c=d&e=f")
eq("url decode", D.encodeUrl("a%20b%26c", { mode: "decode", component: true }).output, "a b&c")
check("url malformed", D.encodeUrl("%zz", { mode: "decode", component: true }).error.length > 0)

// --- jwt -----------------------------------------------------------------
const jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
const decoded = D.decodeJwt(jwt).output
check("jwt header", decoded.includes('"alg": "HS256"'), decoded)
check("jwt payload", decoded.includes('"sub": "1234567890"'), decoded)
check("jwt iat", decoded.includes("iat  2018-01-18T01:30:22.000Z"), decoded)
check("jwt malformed", D.decodeJwt("a.b.c").error.length > 0)

// --- timestamp -----------------------------------------------------------
const ts = D.convertTimestamp("1700000000").output
check("timestamp seconds", ts.includes("2023-11-14T22:13:20.000Z"), ts)
check("timestamp millis", D.convertTimestamp("1700000000000").output.includes("2023-11-14T22:13:20.000Z"))
check("timestamp iso input", D.convertTimestamp("2023-11-14T22:13:20Z").output.includes("1700000000"))
check("timestamp empty is now", Math.abs(Number(D.convertTimestamp("").output.match(/Epoch seconds\s+(-?\d+)/)[1]) - Date.now() / 1000) < 5)
check("timestamp invalid", D.convertTimestamp("not a date").error.length > 0)

// --- colour --------------------------------------------------------------
const red = D.convertColor("#f00").output
check("color hex to rgb", red.includes("rgb(255, 0, 0)"), red)
check("color hex to hsl", red.includes("hsl(0, 100%, 50%)"), red)
check("color rgb input", D.convertColor("rgb(255, 0, 0)").output.includes("HEX  #ff0000"))
check("color hsl input", D.convertColor("hsl(120, 100%, 50%)").output.includes("HEX  #00ff00"))
check("color alpha", D.convertColor("#ff000080").output.includes("rgba(255, 0, 0, 0.50)"))
check("color invalid", D.convertColor("nope").error.length > 0)

// --- regex ---------------------------------------------------------------
const regex = D.testRegex("id=1 id=22", { pattern: "id=(\\d+)", flags: "g" }).output
check("regex count", regex.startsWith("2 matches"), regex)
check("regex groups", regex.includes("group 1: 22"), regex)
check("regex invalid", D.testRegex("x", { pattern: "(" }).error.length > 0)
eq("regex no match", D.testRegex("abc", { pattern: "zzz" }).output, "No match")

// --- diff ----------------------------------------------------------------
const diff = D.textDiff("a\nb\nc", "a\nB\nc").output
check("diff headers", diff.includes("--- Original (3 lines)") && diff.includes("+++ Modified (3 lines)"), diff)
check("diff change", diff.includes("- b") && diff.includes("+ B"), diff)
check("diff counts", diff.includes("@@ -1 +1 @@"), diff)
check("diff identical", D.textDiff("same\ntext", "same\ntext").output.includes("@@ -0 +0 @@"))
const big = Array.from({ length: 1600 }, (_, i) => "line " + i).join("\n")
check("diff limit", D.textDiff(big, big).error.length > 0)

// --- chmod ---------------------------------------------------------------
const chmod = D.describeChmod("755").output
check("chmod octal", chmod.includes("Symbolic  rwxr-xr-x"), chmod)
check("chmod symbolic input", D.describeChmod("rwxr-xr-x").output.includes("Octal     0755"))
check("chmod setuid", D.describeChmod("4755").output.includes("setuid"))
check("chmod sticky", D.describeChmod("1777").output.includes("sticky"))
check("chmod invalid", D.describeChmod("999").error.length > 0)

// --- dispatcher ----------------------------------------------------------
eq("dispatch unknown", D.run("nope", "", {}, rng).error, "Unknown tool: nope")
check("dispatch uuid", D.run("uuid", "", { version: "4" }, rng).output.length === 36)

console.log(failures === 0 ? "ALL TESTS PASSED" : failures + " TEST(S) FAILED")
process.exit(failures === 0 ? 0 : 1)
