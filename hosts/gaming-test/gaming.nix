# Минимум для RF4: gamescope с CAP_SYS_NICE и gamemode (группа из users.nix).
# Steam, Sunshine, input-remapper, uinput-правила и power-tune в тест не входят.
_:

{
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode.enable = true;
}
