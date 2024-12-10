{ lib, pkgs, ... }:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    ;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.programs = {
    winbox.enable = mkEnableOption "Winbox";
    matlab.enable = mkEnableOption "Matlab";
    wireshark.enable = mkEnableOption "Wireshark";
    adb.enable = mkEnableOption "Android Debug Bridge";

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
