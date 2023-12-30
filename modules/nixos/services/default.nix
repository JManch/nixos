{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [
    ./greetd.nix
  ];

  options.modules.services = {

    greetd = {
      enable = mkEnableOption "greetd with tuigreet";
      launchCmd = mkOption {
        type = types.str;
        description = "Login launch command";
        example = "Hyprland";
      };
    };

  };
}
