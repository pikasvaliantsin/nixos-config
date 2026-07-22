{ pkgs, inputs, ... }:
{
  # Устанавливаем Noctalia как системный пакет
  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
