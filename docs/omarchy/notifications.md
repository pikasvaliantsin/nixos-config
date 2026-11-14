# Notifications

The upstream `omarchy.notifications` service is disabled. This port has its own
notification server and center under `shell/Custom/`, with no toast popups.

## Components

- `shell/Custom/Notifications.qml` — the only `NotificationServer` in the
  session. Tracks active notifications, holds the in-session history and the
  DND flag.
- `shell/Custom/NotificationUi.qml` — open/close state and the `notifications`
  IPC target.
- `shell/Custom/NotificationCenter.qml` — the per-output center/card, active
  list, history section, action buttons and Escape handling.
- `shell/Custom/NotificationDismiss.qml` — full-screen click-catcher layer,
  instantiated per screen in `shell/shell.qml`.
- `shell/plugins/bar/widgets/NotificationBell.qml` — `local.notifications` bar
  button; toggles the center.
- `shell/plugins/bar/indicators/Dnd.qml` — Do Not Disturb indicator.

## Server behaviour

`NotificationServer` is configured with:

```qml
keepOnReload: true
actionsSupported: true
bodySupported: true
imageSupported: true
bodyMarkupSupported: false
```

On a new notification:

- if DND is on, it is not tracked at all (no live card, no history);
- otherwise it is tracked and its `closed` signal snapshots it into history.

The tracked model is `server.trackedNotifications`; the count is
`list.values.length`.

## History

History is an in-memory array, newest first, capped at 50 entries. Each entry
is a plain object with `appName`, `appIcon`, `summary`, `body`, `urgency` and
`closedAt`, so it survives the `Notification` object being destroyed by the
server.

History is **not persisted** across a shell restart. If persistence is needed,
write it under a state directory with `FileView` and load it at singleton
startup; do not make the UI depend on the notification objects after they close.

`Clear` in the header dismisses active notifications (they move to history);
`Clear` in the history header empties history. A history card has its own `×`.

## Actions

Live cards render a `Repeater` over `entry.actions`. Each action label comes
from `NotificationAction.text` and is invoked with `modelData.invoke()`.
History entries do not carry live action objects and do not show buttons.

Inline replies are not implemented; the server does not expose
`hasInlineReply` UI here.

## DND

DND currently means "drop new notifications entirely", matching the original
custom center. It is toggled by the `Dnd` bar indicator and the
`notifications dnd` IPC method. There is no queue.

If DND should instead record to history silently, change the
`onNotification` branch in `Notifications.qml` and define what the badge/count
means in that mode.

## Center layout

- one instance per screen (`Variants` over `Quickshell.screens`);
- `visible` is set imperatively by `syncVisible()` when
  `NotificationUi.notificationsOpen` changes or niri emits an event; this
  avoids a binding loop on `screen`/`Niri.focusedOutput`;
- the center card is a small `PanelWindow` at the top-right;
- `NotificationDismiss` is a separate full-screen layer per screen with a
  click-catcher;
- `WlrLayershell.keyboardFocus` is `OnDemand` while visible; `Escape` closes
  the center from an item-level key catcher.

Known issue: with two separate layer surfaces, an outside click can take two
clicks because focus/layer ordering consumes the first one. The intended fix is
to consolidate the center into one full-screen `OverlayWindow` with a scrim
MouseArea, as the clipboard does. Do not add more dismiss layers as a
workaround.

## IPC

Target `notifications`:

```bash
omarchy-ipc call notifications toggle
omarchy-ipc call notifications open
omarchy-ipc call notifications close
omarchy-ipc call notifications clear
omarchy-ipc call notifications dnd
omarchy-ipc call notifications count
omarchy-ipc call notifications quiet
```

There is no `dismiss <summary>` method in the custom center yet; dismiss a
live card by clicking it, or use the clear path. The center does not add a
test-only short timeout.

## Testing

```bash
omarchy-notification-send "Summary" "Body"
omarchy-ipc call notifications open
# click a live card to dismiss it into history
omarchy-ipc call notifications clear   # dismiss all active into history
# use the "Clear" link in the History header to empty history
```

`notify-send` also works for a quick local test, but prefer the Omarchy helper
in runtime code. Check active card, history, time, actions (if the sender
provides them), Escape and click-outside behaviour.
