{ lib, pkgs, ... }:
{
  imports = lib.utils.scanPaths ./.;

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
}
