{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx EDITOR micro
      set -gx VISUAL micro
      set -gx XDG_CURRENT_DESKTOP Niri
      set -gx XDG_SESSION_TYPE wayland
      set -g fish_greeting ""
      set -g __fish_git_prompt_show_informative_status 1
    '';

    interactiveShellInit = ''
          fastfetch
        '';
        
    shellAliases = {
      ls = "lsd";
      ll = "ls -l";
      la = "ls -a";
      tree = "lsd --tree";
      edit = "micro";
      cat = "bat";
      update = "cd ~/nixos-config && sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    };
  };
}
