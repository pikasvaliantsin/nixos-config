# nixos-config/home-manager/modules/editors/dev.nix
{ pkgs, ... }:

{
  # IDE и Dev-инструменты
  home.packages = with pkgs; [
    vscodium
    gcc

    # NixVim сам ставит LSP-серверы из editors.nix; здесь оставляем только
    # то, что нужно вне Neovim (форматтер для CLI/`nix fmt`).
    nixfmt
  ];
}
