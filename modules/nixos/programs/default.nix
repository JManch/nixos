{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./wine.nix
    ./winbox.nix
  ];

  options.modules.programs = {
    winbox.enable = mkEnableOption "Winbox";
    wine.enable = mkEnableOption "Wine";
  };
}
