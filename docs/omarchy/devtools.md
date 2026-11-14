# Developer tools

`Mod+Shift+X` opens a developer toolbox: generators and one-shot text
transformers. It is local code, not an upstream plugin:

- `shell/Custom/DevToolsPanel.qml` — the overlay, tool metadata, secure random
  pool and the native fallbacks;
- `shell/Custom/DevTools.js` — the pure engine. No IO, no timers, no QML
  objects, so every tool is a plain function over strings.

IPC:

```bash
omarchy-ipc call devtools open|close|toggle
omarchy-ipc call devtools tool uuid|password|json|base64|url|jwt|timestamp|color|regex|diff|chmod
omarchy-ipc call devtools option <option-id> <value>
omarchy-ipc call devtools input <text>
omarchy-ipc call devtools compare <original> <modified>
omarchy-ipc call devtools load <path>            # into the current tool
omarchy-ipc call devtools loadOriginal <path>    # diff only
omarchy-ipc call devtools loadModified <path>    # diff only
omarchy-ipc call devtools output|outputSize|outputStart|path|lastError|notice
```

`path` is `js` or `native` for the last run, which makes the fallback testable.
Very large results are not returned over IPC (the socket closes on the
response); use `outputSize`, `outputStart` or `load` for scripted checks.

## Tools

| id | Tool | Notes |
|---|---|---|
| `uuid` | UUID generator | v4 and v7 (time-ordered), count 1/5/10, uppercase, no hyphens |
| `password` | Password generator | per-class characters, unbiased rejection sampling, ambiguity filter |
| `json` | JSON formatter | 2/4 spaces, tab, minify, key sorting, validation errors |
| `base64` | Base64 | encode/decode, URL-safe |
| `url` | URL codec | whole URL or a single component |
| `jwt` | JWT decoder | header, payload, `iat`/`nbf`/`exp` as dates; signature not verified |
| `timestamp` | Unix timestamp | epoch seconds/millis/µs/ns and dates both ways, empty means now |
| `color` | Colour converter | hex, `rgb()`, `rgba()`, `hsl()`, `hsla()` |
| `regex` | Regex tester | JavaScript `RegExp`, every match and group, capped at 200 |
| `diff` | Text diff | LCS line diff with counts; switches to `diff(1)` past 1500 lines |
| `chmod` | chmod calculator | octal ↔ symbolic, setuid/setgid/sticky |

## Fast paths

The QML JavaScript engine has no JIT, so per-byte work is the only slow part.
Everything else is sub-millisecond. Measured on this machine (Qt 6.12, QV4):

| Work | JS engine | Native |
|---|---|---|
| UUID / password | 0.06 ms | — |
| JWT decode | 0.04 ms | — |
| JSON 10 KiB | 1.8 ms | — |
| Base64 100 KiB | ~60 ms | ~2 ms (`base64`) |

So the panel keeps JS for small inputs and hands the big ones to the system
tools, writing a temp file under `$XDG_RUNTIME_DIR/omarchy-devtools` first:

- base64 above 32 KiB → `base64 -w0` / `base64 -d`;
- JSON above 256 KiB → `jq` with the same indent/sort options;
- diff above 1500 lines → `diff -u`.

No shell string is ever built; commands are argv arrays. This is also why there
is no Rust helper: a separate binary would cost 2–5 ms of process start per
call, which is more than every in-process tool except the large-input paths,
and those are already covered by coreutils and jq.

## Secure random

`DevToolsPanel` keeps a 32 KiB pool from `od -An -v -t u1 /dev/urandom` and
refills it when fewer than 16 KiB remain, so generating a UUID never waits on
the kernel. The engine only consumes bytes through `{ byte() }`, which keeps
`DevTools.js` free of QML dependencies and testable under Node.

## Testing

The engine is plain CommonJS-compatible JavaScript:

```bash
nix shell nixpkgs#nodejs -c node tests/devtools-engine.js
```

`tests/devtools-engine.js` strips the `.pragma library` line, then exercises
UUID shapes and v7 timestamps, password classes, Base64 round-trips, JSON
sorting, URL escaping, JWT claims, timestamp parsing, colour conversion, regex
groups, diff counts, chmod special bits and the dispatcher.
