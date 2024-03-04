{ lib, pkgs, ... } @ args:
let
  inherit (lib) mkEnableOption mkOption utils fetchers types;
  homeConfig = utils.homeConfig args;
  isWayland = fetchers.isWayland homeConfig;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs = {
    winbox.enable = mkEnableOption "Winbox";
    matlab.enable = mkEnableOption "Matlab";

    wine = {
      enable = mkEnableOption "Wine";
      package = mkOption {
        type = types.package;
        default = with pkgs.wine64Packages; if isWayland then wayland else stable;
        description = "The default wine package to use";
      };
    };
  };
}
