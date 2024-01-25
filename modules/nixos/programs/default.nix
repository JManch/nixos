{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./wine.nix
    ./winbox.nix
    ./matlab.nix
    ./gaming
  ];

  options.modules.programs = {
    winbox.enable = mkEnableOption "Winbox";
    wine.enable = mkEnableOption "Wine";
    matlab.enable = mkEnableOption "Matlab";
  };
}
