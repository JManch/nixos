{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./wine.nix
    ./winbox.nix
    ./steam.nix
    ./gamemode.nix
    ./matlab.nix
  ];

  options.modules.programs = {
    winbox.enable = mkEnableOption "Winbox";
    wine.enable = mkEnableOption "Wine";
    gaming.enable = mkEnableOption "Gaming";
    matlab.enable = mkEnableOption "Matlab";
  };
}
