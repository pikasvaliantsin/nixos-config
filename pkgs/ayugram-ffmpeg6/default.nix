# AyuGram, у которого tg_owt собран против того же ffmpeg, что и само
# приложение (6.1.6). Иначе AVCodecContext читается по смещениям ffmpeg 9,
# и первое же H.264-видео (демонстрация экрана) роняет клиент на
# RTC_CHECK_EQ(context->lowres, 0).
{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  base = inputs.ayugram-desktop.packages.${system}.default;

  tgOwt = inputs.tg_owt.packages.${system}.default;
  tgOwtFfmpeg6 = tgOwt.overrideAttrs (old: {
    propagatedBuildInputs = map (
      p: if (p.pname or "") == "ffmpeg" then pkgs.ffmpeg_6 else p
    ) (old.propagatedBuildInputs or [ ]);
  });
in
base.override { tg_owt = tgOwtFfmpeg6; }
