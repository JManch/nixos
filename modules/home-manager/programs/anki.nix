{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (config.modules.desktop) isWayland;
  cfg = config.modules.programs.anki;
in
mkIf cfg.enable {
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables = mkIf isWayland { ANKI_WAYLAND = 1; };
  };

  backups.anki.paths = [ ".local/share/Anki2" ];

  persistence.directories = [ ".local/share/Anki2" ];
}
