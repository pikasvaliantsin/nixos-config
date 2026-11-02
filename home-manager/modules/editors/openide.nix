# OpenIDE — IDE на платформе IntelliJ IDEA (https://openide.ru).
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ../../../pkgs/openide { })
  ];
}
