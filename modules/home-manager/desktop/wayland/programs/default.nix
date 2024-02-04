{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop.programs = {
    swaylock = {
      enable = mkEnableOption "swaylock";
      lockScript = mkOption {
        type = types.str;
        description = "Path to script that locks the screen";
        default = (pkgs.writeShellScript "swaylock-lock" ''
          ${config.swaylock.package}/bin/swaylock -f
        '').outPath;
      };
    };
    anyrun.enable = mkEnableOption "anyrun";
  };
}
