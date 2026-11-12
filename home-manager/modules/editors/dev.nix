# IDE и Dev-инструменты: Zed вместо VSCodium.
{ lib, pkgs, ... }:

let
  flake = "/home/valen/nixos-config";
in
{
  home.packages = with pkgs; [
    gcc

    # NixVim сам ставит LSP-серверы из editors.nix; здесь оставляем только
    # то, что нужно вне Neovim (форматтер для CLI/`nix fmt`).
    nixfmt
  ];

  programs.zed-editor = {
    enable = true;

    # Подсветка синтаксиса Nix (tree-sitter) + определения nixd/nil.
    extensions = [ "nix" ];

    # nixd и nixfmt доступны внутри обёрнутого Zed.
    extraPackages = with pkgs; [
      nixd
      nixfmt
    ];

    userSettings = {
      format_on_save = "on";
      show_completions_on_input = true;

      lsp.nixd = {
        binary.path = lib.getExe pkgs.nixd;

        initialization_options = {
          # Форматирование через nixfmt.
          formatting.command = [ (lib.getExe pkgs.nixfmt) ];

          # Автодополнение имён пакетов из nixpkgs этого флейка.
          nixpkgs.expr = "import (builtins.getFlake \"${flake}\").inputs.nixpkgs { }";

          # Автодополнение и валидация опций NixOS (nixos.*).
          options.nixos.expr = "(builtins.getFlake \"${flake}\").nixosConfigurations.asus-expertbook.options";
        };
      };

      languages."Nix" = {
        # nil не установлен — используем только nixd.
        language_servers = [ "nixd" ];
        formatter.external = {
          command = lib.getExe pkgs.nixfmt;
          arguments = [ ];
        };
      };
    };
  };
}
