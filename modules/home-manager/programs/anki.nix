{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) ns mkIf;
  cfg = config.${ns}.programs.anki;
in
mkIf cfg.enable {
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables.ANKI_WAYLAND = 1;
  };

  backups.anki.paths = [ ".local/share/Anki2" ];

  persistence.directories = [ ".local/share/Anki2" ];
}
