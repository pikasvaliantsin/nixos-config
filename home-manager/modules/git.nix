{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Valentin Pikas";
        email = "pikasvaliantsin@github.com";
      };
      core.editor = "micro";
      init.defaultBranch = "main";
      color.ui = true;
      alias = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        lg = "log --oneline --graph --all";
      };
    };
  };
}
