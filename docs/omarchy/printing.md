# Print folder

A single folder is a print queue. Files dropped into it are listed in the bar
widget's panel; one button sends the new ones to CUPS. Every document keeps a
printed/not-printed state with the time of the last successful job, and a
printed document can be checked again and reprinted.

## Using it

- Left click the printer icon in the bar (next to OpenCode) to open the panel.
- Right click the icon opens the folder in the file manager.
- **Print new** sends every document that has no recorded print job.
- Each row is a checkbox. A row seen for the first time starts checked when it
  has not been printed; printed rows start unchecked.
- Check a printed row and press **Print selected** to reprint it. **Select
  new** checks all unprinted documents again, **Clear** empties the selection.
- The number beside the bar icon is the count of unprinted/changed documents.
- Hovering a row pins the preview to that document (the keyboard cursor moves
  with the pointer, so the preview stays after the pointer leaves the row).
- Hover the preview, click it, press its expand button, or press `f` to open a
  document-sized reader. A4 is shown at its natural 96 dpi width, not stretched
  across the monitor. The reader scrolls with the wheel/touchpad, arrows,
  PageUp/PageDown, Space, Home and End. Escape or a click outside closes it.
- In the panel, Up/Down move the row cursor, Space/Enter toggles the current
  row, `r` refreshes, Escape closes.

A document is "changed" when its contents no longer match the hash recorded
for the last print. It is then listed as **Changed since last print** and
counts as new, so the next **Print new** prints the new version.

## Folder and printer

Defaults:

```text
folder   ~/Documents/Print
status   ~/.local/state/omarchy/print/status.json
printer  first line of ~/.config/omarchy/print/printer, else the CUPS
         default destination, else the first printer in `lpstat -p`
```

The helper creates the folder and state directory on first use. To use another
folder, write its absolute path (or a `~/` path) to
`~/.config/omarchy/print/folder`. `OMARCHY_PRINT_DIR` overrides both for a
one-off run.

The printer is the CUPS queue name shown by `lpstat -p`; this machine's queue
is `Pantum_M6500W_Series_A4E76B`. `lpstat -d` reporting no system default is
fine: the helper falls back to the first available printer.

## Formats

Printed directly by CUPS: PDF, PNG, JPEG, WebP and plain text. DOCX and ODT
are converted with headless LibreOffice when `libreoffice` is on `PATH`; this
system does not install it, so those two are skipped with a message. Convert
such a document to PDF before dropping it in.

Previews use `pdftoppm` (poppler-utils, a shell runtime dependency). The inline
thumbnail is the first page at low resolution, cached as
`~/.local/state/omarchy/print/preview/<sha256>.png`. The natural-size reader
renders every page at 150 dpi into
`~/.local/state/omarchy/print/preview/<sha256>-150/page-*.png` and displays it
at 96 dpi scale. Changing the file changes the hash and makes a fresh render.
DOCX/ODT have no preview.

Files are copied to CUPS as they are; the folder is not a staging area and
nothing is moved or deleted after printing.

## Status and reprinting

`status.json` maps the absolute document path to:

```json
{
  "/home/user/Documents/Print/receipt.pdf": {
    "hash": "sha256 of the file that was printed",
    "printedAt": "2026-11-15T09:41:00+03:00",
    "jobId": "Pantum_M6500W_Series_A4E76B-42",
    "printer": "Pantum_M6500W_Series_A4E76B"
  }
}
```

The panel only reports **Printed** while the current file hash equals the
recorded hash. Replacing a file with another copy under the same name changes
the hash and makes it new again. Deleting a file leaves its record in place;
`omarchy-print forget <path>` removes one. The file is created mode `0600`
because document names can be sensitive.

## Command line

```bash
omarchy-print list                    # JSON: folder, printer, documents
omarchy-print print --new            # everything not printed at its current hash
omarchy-print print -- file1 file2   # an explicit selection (reprints allowed)
omarchy-print print --dry-run --new  # show the selection, send nothing
omarchy-print preview <file>         # cached first-page thumbnail path
omarchy-print pages <file>           # JSON: natural-size page images, count, scale
omarchy-print printer                # resolved queue name
omarchy-print folder                 # resolved folder
omarchy-print forget <file>          # drop one status record
```

The panel runs the same helper through
`systemd-run --user --scope --slice=app.slice`, with the helper's absolute path
from `OMARCHY_PATH`: a print batch therefore does not inherit
`omarchy-shell.service`'s cgroup and survives a shell restart. The helper is
short-lived; the scope is not used from the command line.

## Files

- `vendor/omarchy-shell/bin/omarchy-print` — list/print/status helper.
- `vendor/omarchy-shell/shell/Custom/PrintService.qml` — polling, selection
  and print process (one per shell, shared by both bars).
- `vendor/omarchy-shell/shell/Custom/PrintPanel.qml` — panel UI and inline
  hover preview.
- `vendor/omarchy-shell/shell/Custom/PrintPreviewOverlay.qml` — natural-size
  multi-page reader (Escape/outside click, wheel and key scrolling).
- `vendor/omarchy-shell/shell/plugins/bar/widgets/PrintQueue.qml`,
  `PrintQueue.manifest.json` — bar icon and manifest (`local.print`).
- `home-manager/modules/desktop/omarchy/shell.json` — `local.print` in the
  right bar section.
- `pkgs/omarchy-shell/default.nix` — `cups` and `poppler-utils` runtime
  dependencies for `lp`, `lpstat`, `cancel` and `pdftoppm`; the profile's
  `omarchy-print` is also wrapped with that PATH.

The service polls `omarchy-print list` every 20 seconds so the bar badge is
current while the panel is closed. There is no directory-level signal for
"file dropped in this folder and its hash changed", so the short JSON helper
is the source of truth; keep the timer in `PrintService`, not in the panel or
per-monitor widget.

## Troubleshooting

- **No CUPS printer found** — check `lpstat -p`; the queue must be enabled and
  accepting jobs. Write a queue name to `~/.config/omarchy/print/printer` to
  override the fallback.
- **A job fails** — the panel shows `omarchy-print`'s error line; check
  `lpstat -o` and the CUPS journal. Successfully recorded files stay printed.
- **A document prints twice** — its hash changed (or the status file was
  removed). Use `omarchy-print list` to see `printed`/`changed` for each file.
- **DOCX/ODT skipped** — install LibreOffice or convert to PDF. Printing uses
  LibreOffice when it is installed, but this system does not include it, so
  DOCX/ODT currently have neither printing nor preview. Legacy `.doc` is not
  supported either.
- **Preview says "No preview for this format"** — only PDF, images and text
  preview inline; the natural-size reader supports PDF and images. Convert
  DOCX/ODT to PDF. A broken/encrypted PDF shows the `pdftoppm` error instead.
