{ lib
, config
, ...
}:
with lib; {
  imports = [
    ./services/dunst.nix
  ];
  options.modules.desktop = {
    dunst.enable = mkEnableOption "Dunst";
  };
}
