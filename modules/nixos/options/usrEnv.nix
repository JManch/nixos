{ lib, username, ... }:
let
  inherit (lib) mkEnableOption mkOption;
in
{
  options.usrEnv = {
    homeManager.enable = mkEnableOption "Home Manager";

    username = mkOption {
      internal = true;
      readOnly = true;
      default = username;
      description = ''
        Used for getting the username of a given nixosConfiguration.
      '';
    };
  };
}
