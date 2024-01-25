{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [
    ./steam.nix
    ./gamemode.nix
    ./gamescope.nix
  ];

  options.modules.programs.gaming = {
    enable = mkEnableOption "enable system gaming optimisations";
    windowClassRegex = mkOption {
      type = types.str;
      default = "^(steam_app.*|\.gamescope.*)$";
      description = "Regex to match game window classes";
    };
    steam.enable = mkEnableOption "steam";
    gamescope.enable = mkEnableOption "gamescope";
    gamemode.enable = mkEnableOption "gamemode";
  };
}
