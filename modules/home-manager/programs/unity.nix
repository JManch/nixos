{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.unity;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.unityhub ];

  persistence.directories = [
    "Unity" # yuck
    ".config/unity3d"
    ".local/share/unity3d"
    ".config/unityhub"
  ];
}
