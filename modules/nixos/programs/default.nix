{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs = {
    winbox.enable = mkEnableOption "Winbox";
    matlab.enable = mkEnableOption "Matlab";
    wireshark.enable = mkEnableOption "Wireshark";

    wine = {
      enable = mkEnableOption "Wine";
      package = mkOption {
        type = types.package;
        default = pkgs.wineWowPackages.stable;
        description = "The default wine package to use";
      };
    };
  };
}
