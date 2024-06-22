{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers;
  cfg = config.modules.programs.anki;
in
mkIf cfg.enable
{
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables = mkIf (fetchers.isWayland osConfig) {
      ANKI_WAYLAND = 1;
    };
  };

  backups.anki.paths = [ ".local/share/Anki2" ];

  persistence.directories = [ ".local/share/Anki2" ];
}
