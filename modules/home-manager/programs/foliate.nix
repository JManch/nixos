{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.foliate;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.foliate ];
  persistence.directories = [
    ".local/share/com.github.johnfactotum.Foliate"
  ];
}
