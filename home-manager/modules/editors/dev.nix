# nixos-config/home-manager/modules/editors/dev.nix
{ pkgs, ... }:

{
  # IDE и Dev-инструменты
  home.packages = with pkgs; [
    vscodium
    gcc

    # LSP-серверы (standalone для CLI и для Neovim)
    nixd
    nixfmt
    bash-language-server
    yaml-language-server
    taplo
    lua-language-server
  ];
}
