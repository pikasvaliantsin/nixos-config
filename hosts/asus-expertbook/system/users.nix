{ pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.valen = {
    isNormalUser = true;
    hashedPasswordFile = "/run/secrets/valen_password";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "input"
      "render"
      "networkmanager"
      "lp"
      "scanner"
    ];
    shell = pkgs.fish;
  };
}
