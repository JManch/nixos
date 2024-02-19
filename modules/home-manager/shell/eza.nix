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
    EZA_COLORS = "di=34:bd=33:cd=33:so=31:ex=32:ur=33:uw=31:ux=32:ue=32:uu=33:gu=33:lc=31:df=32:sn=32:nb=32:nk=32:nm=32:ng=32:nt=32";
  };
}
