{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    mkOption
    mkDefault
    mkForce
    types
    ;
  inherit (config.${ns}.core) device;
in
{
  opts.namespace = mkOption {
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

  _module.args = {
    inherit (cfg.users) adminUsername;
  };

  time.timeZone = mkDefault "Europe/London";

  services.tzupdate = {
    enable = device.type == "laptop";
    timer.enable = false;
  };

  # Would rather run service manually when we are away from home
  systemd.services.tzupdate = mkIf (device.type == "laptop") {
    wantedBy = mkForce [ ];
  };

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };
}
