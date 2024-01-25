{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./mangohud.nix
    ./r2modman.nix
    ./lutris.nix
    ./steam.nix
  ];

  options.modules.programs.gaming = {
    mangohud.enable = mkEnableOption "mangohud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "lutris";
  };
}
