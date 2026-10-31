# Автоматическое монтирование съёмных носителей.
_:

{
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };
}
