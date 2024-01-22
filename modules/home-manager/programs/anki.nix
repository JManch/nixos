{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.anki;
in
lib.mkIf cfg.enable
{
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables = lib.mkIf (lib.fetchers.isWayland config) {
      ANKI_WAYLAND = 1;
    };
  };

  impermanence.directories = [
    ".local/share/Anki2"
  ];
}
