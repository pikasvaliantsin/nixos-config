# Notifications

The upstream `omarchy.notifications` service is disabled. This port has its own
notification server and center under `shell/Custom/`, with no toast popups.

## Components

- `shell/Custom/Notifications.qml` — the only `NotificationServer` in the
  session. Tracks active notifications, persists history and the DND flag.
- `shell/Custom/NotificationUi.qml` — open/close state and the `notifications`
  IPC target.
- `shell/Custom/NotificationCenter.qml` — the center overlay, active list,
  history section, action buttons and Escape handling.
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

- if DND is on, it is recorded in history immediately and is not tracked as a
  live card;
- otherwise it is tracked and its `closed` signal snapshots it into history.

The tracked model is `server.trackedNotifications`; the count is
`list.values.length`, so it counts live cards only and stays `0` under DND.

## History

History is newest first, capped at 50 entries. Each entry is a plain object
with `appName`, `appIcon`, `summary`, `body`, `urgency`, `closedAt` and
`dnd`, so it survives the `Notification` object being destroyed by the
server.

It is persisted under `~/.local/state/omarchy/notifications/`:

```text
history.json   array of history entries
quiet.json     {"dnd": true|false}
```

`home-manager/modules/desktop/omarchy.nix` creates the directory as `0700` and
the files as `0600`; the shell writes them atomically with `FileView`. The
singleton loads history and DND when the shell starts.

`Clear` in the header dismisses active notifications (they move to history);
`Clear` in the history header empties history and its file. A history card has
its own `×`. DND notifications appear in history with `"dnd": true` and no live
card.

## Actions

Live cards show buttons built by `Notifications.actionsFor()`:

- Omarchy helper actions from the `omarchy-actions` hint, which is what
  `omarchy-notification-send --action <label> <program> [words...]` writes.
  The parser caps the hint at three buttons and validates each argv; buttons
  run through `Util.execArgv`, never through a shell string.
- the sender's standard D-Bus actions from `NotificationAction.text`, invoked
  with `action.invoke()`. The `default` action is skipped so it does not
  appear as a duplicate button; card-click in this center still dismisses
  rather than invoking it.

History entries do not carry live action objects and do not show buttons.

Live cards with `hasInlineReply` show a reply field. `Enter` sends through
`Notification.sendInlineReply()` and dismisses the notification; `Escape` in
the field closes just the field. `inlineReplySupported` is enabled on the
server. History entries have no reply field.

## Toasts

Toasts are optional and **off by default**. Toggle them with the `Toasts`
control in the center header or `notifications toasts` IPC; the choice is
persisted in `quiet.json` next to DND. When enabled, a notification also shows
a small top-right toast for five seconds, with hover pause, click-to-center and
a close button. They do not take keyboard focus. DND suppresses toasts.

## DND

DND means "no live card and no toast, but keep it in history". It is toggled by
the `Dnd` bar indicator and the `notifications dnd` IPC method, and the state is
persisted in `quiet.json` across shell restarts. There is no queue; history is
the queue. The badge/count remains the number of live cards, not hidden DND
entries.

## Center layout

- one `NotificationCenter` instance in `shell.qml`;
- Recent tab: live notifications plus notifications closed in this shell
  session, grouped by app name; a group header shows the count and latest
  summary and expands to its cards. History tab: persisted closed entries,
  newest first;
- the center is one full-screen `OverlayWindow` on the focused output, like
  the clipboard. Its scrim `MouseArea` catches an outside click, the card at
  the top-right stops clicks from reaching the scrim, and an item-level key
  catcher closes on `Escape`;
- `WlrLayershell.keyboardFocus` is `OnDemand` while open; the key catcher
  receives focus when the overlay is shown;
- because the scrim, card and key catcher are one layer surface, an outside
  click closes the center on the first click. Do not add a separate dismiss
  layer; that was the old two-surface design and swallowed the first click.

## IPC

Target `notifications`:

```bash
omarchy-ipc call notifications toggle
omarchy-ipc call notifications open
omarchy-ipc call notifications close
omarchy-ipc call notifications clear
omarchy-ipc call notifications dnd
omarchy-ipc call notifications toasts
omarchy-ipc call notifications count
omarchy-ipc call notifications quiet
```

There is no `dismiss <summary>` method in the custom center yet; dismiss a
live card by clicking it, or use the clear path. The center does not add a
test-only short timeout.

## Testing

```bash
omarchy-notification-send "Summary" "Body"
omarchy-notification-send "Action" "Body" --action "Mark read" true
omarchy-ipc call notifications open
# click a live card to dismiss it into history
omarchy-ipc call notifications clear   # dismiss all active into history
# use the "Clear" link in the History header to empty history
```

`notify-send` also works for a quick local test, but prefer the Omarchy helper
in runtime code. Check active card, history, time, action buttons (the
`--action` helper path and, if the sender provides them, standard D-Bus
actions), inline reply where supported, Recent/History tabs, grouping,
optional toasts, Escape and click-outside behaviour.

To check persistence:

```bash
omarchy-ipc call notifications dnd          # quiet=on
omarchy-notification-send "Quiet" "Kept in history"
cat ~/.local/state/omarchy/notifications/history.json
cat ~/.local/state/omarchy/notifications/quiet.json
systemctl --user restart omarchy-shell
omarchy-ipc call notifications quiet        # still on
```

A DND notification must not increase `notifications count`, must appear in the
History section, and must survive the restart. Turn DND off with the same IPC
call before testing live cards again.
