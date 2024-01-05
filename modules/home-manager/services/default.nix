{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./syncthing.nix
  ];

  options.modules.services = {
    syncthing.enable = mkEnableOption "Syncthing";
  };
}
