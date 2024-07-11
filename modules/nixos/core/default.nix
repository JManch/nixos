{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) utils mkOption mkEnableOption types;
in
{
  imports = utils.scanPaths ./.;

  options.modules.core = {
    homeManager.enable = mkEnableOption "Home Manager";
    autoUpgrade = mkEnableOption "auto upgrade";

    username = mkOption {
      type = types.str;
      readOnly = true;
      default = username;
      description = "The username of the primary user of the nixosConfiguration";
    };

    adminUsername = mkOption {
      type = types.str;
      readOnly = true;
      default = "joshua";
      description = "The username of the admin user that exists on all hosts";
    };

    priviledgedUser = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the host's primary user is part of the wheel group
      '';
    };
  };

  config = {
    programs.zsh.enable = true;
    environment.systemPackages = [ pkgs.gitMinimal ];

    _module.args = { inherit (config.modules.core) adminUsername; };

    security.sudo.extraConfig = "Defaults lecture=never";
    time.timeZone = "Europe/London";

    environment.sessionVariables = {
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
  };
}
