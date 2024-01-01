{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./wine.nix
    ./winbox.nix
    ./steam.nix
  ];

  options.modules.programs = {
    winbox.enable = mkEnableOption "Winbox";
    wine.enable = mkEnableOption "Wine";
    steam.enable = mkEnableOption "Steam";
  };
}
