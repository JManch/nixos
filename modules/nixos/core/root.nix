{
  lib,
  cfg,
  pkgs,
}:
{
  opts.namespace =
    with lib;
    mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = ns;
    };

  programs.zsh.enable = true;
  environment.defaultPackages = [ ];

  environment.systemPackages = with pkgs; [
    gitMinimal
    fd
    tree
    rsync
  ];

  _module.args.adminUsername = cfg.users.adminUsername;

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };
}
