# Motion

Read this before adding or changing an animation in
`vendor/omarchy-shell/shell/`.

Every animation needs a reason: it shows where something came from or went,
confirms an input, or keeps a change from jumping. "It looks nice" on
something seen many times a day is not a reason. Verify motion frame by frame
as described in [`visual-verification.md`](visual-verification.md).

## Should it animate

- Frequently used single-keystroke surfaces stay instant: menu, launcher,
  clipboard picker, emoji picker, OSD.
- A keystroke that acts and is done (dismiss notification, dismiss all, invoke)
  jumps rather than animating.
- Inside a surface the user stays and watches, pointer and keyboard get the
  same motion: panels opened by hotkey grow/fade like a click.
- Hover effects stay small and quick.

## Tokens

- Every duration goes through `Style.duration(ms)`. It returns 0 when
  `Style.reduceMotion` is true.
- `Style.reduceMotion` exists, but this niri port does not currently expose the
  upstream `omarchy toggle animations` command. Set it manually only when
  implementing reduced-motion support; do not write bare durations.
- Movement/entrances use `Style.easeOut` with
  `easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut`.
  Plain fades may use `Easing.OutCubic`; hover color changes
  `Easing.InOutQuad`.
- Never ease-in for UI. No overshoot or bounce. No `Easing.Linear` except
  constant motion such as a spinner.
- Looping animations need `running: ... && !Style.reduceMotion`.

## Durations

- UI motion stays under 300ms; entrances 180–250ms.
- Leaving is faster than arriving, about two thirds: panels open in 180ms and
  close in 120ms; notification-style cards arrive in 250ms and leave in 200ms.
- Text fading out under something fading in takes half the fade-in time.
- Press feedback 160ms.

## Existing patterns

Build on these instead of writing a new animation:

- `KeyboardPanel.qml` — grows from 0.97 from the bar-facing edge nearest the
  icon (`growOrigin`) and fades; panel-to-panel takeover uses
  `morphFromLastCard` / `bar.popoutCardFor()`.
- `PopupCard.qml` — the same grow/fade for tray/media popups.
- `Button.qml` — press scales to 0.97; hit area compensates with `1 / scale`.
- `OverlayWindow.qml` — used by the clipboard; maps a fresh full-screen
  surface, reveals content once scale/geometry are ready.
- Notification deck (upstream) — one scene clock; our custom center is
  deliberately simple and does not reuse the deck.

## Pitfalls

- Never scale from 0. Start at 0.95–0.97 with opacity 0.
- Scaling scales the hit area; undo it on the mouse area.
- Animating height while content reflows every frame is expensive; size to the
  final height and crop while the frame catches up.
- A `Behavior` that must not run for one change needs its `enabled` condition
  true before the value changes.
- A global `Style.reduceMotion` cuts already-running animations; keep instant
  paths local when possible.
