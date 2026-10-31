# Автоматическое монтирование съёмных носителей.
{ ... }:

{
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };
}
