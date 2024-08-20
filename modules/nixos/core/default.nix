{
  lib,
  pkgs,
  config,
  username,
  adminUsername,
  ...
}:
let
  inherit (lib)
    utils
    mkOption
    mkEnableOption
    types
    mkAliasOptionModule
    ;
in
{
  imports = utils.scanPaths ./. ++ [
    (mkAliasOptionModule [ "userPackages" ] [
      "users"
      "users"
      username
      "packages"
    ])

    (mkAliasOptionModule [ "adminPackages" ] [
      "users"
      "users"
      adminUsername
      "packages"
    ])
  ];

  options.modules.core = {
    homeManager.enable = mkEnableOption "Home Manager";
    autoUpgrade = mkEnableOption "auto upgrade";

    builder = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this host is a high-performance nix builder";
    };

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
    environment.defaultPackages = [ ];
    environment.systemPackages = [ pkgs.gitMinimal ];

    _module.args = {
      inherit (config.modules.core) adminUsername;
    };

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
