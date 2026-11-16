# shellcheck shell=bash
# Make the Dux file manager the handler for folders and file-manager URL
# schemes. The previous mimeapps.list was left over from DankMaterialShell:
# it pointed at a missing dms-open.desktop and listed Obsidian as a folder
# handler, so GIO/xdg-open disagreed about the default.

set -euo pipefail

desktop="dev.duxlabs.files.desktop"
file="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"

mkdir -p "$(dirname "$file")"
if [ -f "$file" ]; then
  [ -e "$file.bak-omarchy" ] || cp -a "$file" "$file.bak-omarchy"
  sed -i '/dms-open\.desktop/d' "$file"
  sed -i \
    -e 's|^inode/directory=.*|inode/directory=dev.duxlabs.files.desktop|' \
    -e 's|^x-scheme-handler/file=.*|x-scheme-handler/file=dev.duxlabs.files.desktop|' \
    -e 's|^x-scheme-handler/sftp=.*|x-scheme-handler/sftp=dev.duxlabs.files.desktop|' \
    -e 's|^x-scheme-handler/smb=.*|x-scheme-handler/smb=dev.duxlabs.files.desktop|' \
    -e 's|^x-scheme-handler/trash=.*|x-scheme-handler/trash=dev.duxlabs.files.desktop|' \
    "$file"
fi

for mime in \
  inode/directory \
  x-scheme-handler/file \
  x-scheme-handler/sftp \
  x-scheme-handler/smb \
  x-scheme-handler/trash
do
  xdg-mime default "$desktop" "$mime" >/dev/null 2>&1 || true
done

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications" >/dev/null 2>&1 || true
fi
