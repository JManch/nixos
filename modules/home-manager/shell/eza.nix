{ lib, config, ... }:
lib.mkIf config.modules.shell.enable
{
  programs.eza = {
    enable = true;
    enableAliases = false;
    git = true;
    icons = true;
  };

  programs.zsh.shellAliases = {
    ls = "eza";
    ll = "eza -la";
    la = "eza -a";
  };

  home.sessionVariables = {
    EZA_COLORS = "di=34;1:mp=34;1:bu=33;1:cm=90";
  };
}
