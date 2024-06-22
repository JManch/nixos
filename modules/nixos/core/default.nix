{ lib, pkgs, username, ... }:
let
  inherit (lib) mkOption mkEnableOption;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.core = {
    homeManager.enable = mkEnableOption "Home Manager";
    autoUpgrade = mkEnableOption "auto upgrade";

    username = mkOption {
      internal = true;
      readOnly = true;
      default = username;
      description = ''
        Used for getting the username of a given nixosConfiguration.
      '';
    };
  };

  config = {
    environment.systemPackages = [
      pkgs.git
    ];

    security.sudo.extraConfig = "Defaults lecture=never";
    time.timeZone = "Europe/London";
    system.stateVersion = "23.05";

    programs.zsh.enable = true;

    environment.sessionVariables = {
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
  };
}
