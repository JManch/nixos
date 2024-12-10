{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.desktop) isWayland;
  cfg = config.${ns}.programs.anki;
in
mkIf cfg.enable {
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables = mkIf isWayland { ANKI_WAYLAND = 1; };
  };

  backups.anki.paths = [ ".local/share/Anki2" ];

  persistence.directories = [ ".local/share/Anki2" ];
}
