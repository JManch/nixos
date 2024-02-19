{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf fetchers;
  cfg = config.modules.programs.anki;
in
mkIf cfg.enable
{
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables = mkIf (fetchers.isWayland config) {
      ANKI_WAYLAND = 1;
    };
  };

  persistence.directories = [ ".local/share/Anki2" ];
}
