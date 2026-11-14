# Graphical sudo authentication

`sudo` uses the normal PAM service `sudo`. This port inserts a `pam_exec`
rule before `pam_fprintd` and `pam_unix`; it asks the Quickshell auth dialog for
a password or fingerprint and verifies the answer itself.

## Flow

1. A terminal `sudo`, or `omarchy-sudo-passwordless` from the bar menu, starts
   authentication.
2. `pam_exec` runs `omarchy-pam-auth` as root.
3. The helper connects to `$XDG_RUNTIME_DIR/omarchy-auth.sock` (derived from
   `PAM_USER`'s UID) and sends an `auth_request`.
4. `AuthAgent` shows one modal dialog on the focused output with:
   - a password field, usable immediately;
   - a fingerprint button and an automatically started scan.
5. The dialog sends either a password or a fingerprint request. The helper:
   - checks a password with `pamtester omarchy-password <user> authenticate`;
   - runs `fprintd-verify <user>` itself for fingerprint.
6. A success returns PAM success; a wrong password or failed scan leaves the
   dialog open so the user can retry or switch method without a terminal
   fallback.

The GUI is not trusted for success. A fake socket peer can choose password or
fingerprint, but the root helper still needs the real password or a real
fingerprint.

## PAM order

```pam
auth [success=done auth_err=die default=ignore] pam_exec.so /nix/store/...-omarchy-pam-auth
auth sufficient pam_fprintd.so
auth sufficient pam_unix.so likeauth try_first_pass
auth required pam_deny.so
```

- success: stop, sudo proceeds;
- `auth_err` (Cancel): deny immediately, do not fall back to a terminal
  fingerprint prompt;
- other errors (no graphical session, helper could not start): ignore and let
  the normal fprintd/password stack handle it.

The password check uses a separate PAM service, `omarchy-password`, with only
`pam_unix`. It must never include `pam_fprintd`, otherwise a password choice
would invoke the sequential fingerprint prompt this feature is meant to avoid.

## Files

- `hosts/asus-expertbook/system/omarchy-sudo.nix` — PAM rules, helper wrapper.
- `hosts/asus-expertbook/system/omarchy-pam-auth.py` — root-side helper.
- `vendor/omarchy-shell/shell/Custom/AuthAgent.qml` — socket server and dialog.
- `vendor/omarchy-shell/shell/Custom/SudoMenu.qml` — starts
  `omarchy-sudo-passwordless` directly, with no terminal.
- `vendor/omarchy-shell/shell/shell.qml` — one `AuthAgent` instance.

The helper script embeds the absolute `pamtester` and `fprintd-verify` paths in
the Nix wrapper; it does not rely on the session `PATH`.

## Testing

Use the PAM stack directly, which avoids changing sudo timestamps:

```bash
nix shell nixpkgs#pamtester -c pamtester sudo "$USER" authenticate </dev/null
```

The dialog should open. Check:

- fingerprint works with the sensor;
- typing a password works immediately and cancels the scan;
- a wrong password shows `Wrong password` and keeps the dialog;
- a failed fingerprint keeps the dialog;
- Cancel closes the dialog and makes `pamtester` exit non-zero without starting
  a terminal fingerprint prompt.

Do UI checks only when the desktop is on a safe workspace; do not send test
keys while a game or another full-screen app is focused.

`sudo` itself can be checked with a harmless command after the timestamp has
expired:

```bash
sudo -k
sudo true
```

## Passwordless sudo menu

`SudoMenu` runs `omarchy-sudo-passwordless <minutes>` without
`omarchy-launch-sudo-terminal`. That script still calls `sudo`, so the same
graphical dialog authenticates enabling the temporary sudoers rule. The
`omarchy-launch-sudo-terminal` helper remains for other manual uses.
