{ lib
, config
, ...
}:
with lib; {
  imports = [
    ./services/dunst.nix
  ];
  options.modules.desktop = {
    dunst = {
      enable = mkEnableOption "Dunst";
      monitorNumber = mkOption {
        type = types.int;
        default = 1;
        description = "The monitor number to display notifications on";
      };
    };
  };
}
