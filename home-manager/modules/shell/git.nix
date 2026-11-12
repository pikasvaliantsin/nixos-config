# Git: глобальные настройки и короткие алиасы.
_:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Valentin Pikas";
        email = "pikasvaliantsin@github.com";
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
      color.ui = true;
      # Любой https://github.com/... автоматически идёт по SSH: иначе git
      # просит username/токен вместо того, чтобы взять ключ.
      url."git@github.com:".insteadOf = "https://github.com/";
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
