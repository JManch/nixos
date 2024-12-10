{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${lib.ns}.programs.foliate;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.foliate ];
  persistence.directories = [
    ".local/share/com.github.johnfactotum.Foliate"
    # Book covers do not show if cache is deleted
    ".cache/com.github.johnfactotum.Foliate"
  ];
}
