{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [
    ./greetd.nix
    ./syncthing.nix
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

    syncthing = {
      enable = mkEnableOption "syncthing";
      # Only one host in a syncthing net should have this enabled
      shareNotes = mkEnableOption "share notes directory";
    };

  };
}
