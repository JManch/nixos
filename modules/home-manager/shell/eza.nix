{ lib, config, ... }:
lib.mkIf config.modules.shell.enable
{
  programs.eza = {
    enable = true;
    git = true;
    icons = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    enableIonIntegration = false;
    enableNushellIntegration = false;
  };

  programs.zsh.shellAliases = {
    ls = "eza";
    ll = "eza -la -snew";
    la = "eza -a -snew";
  };

  home.sessionVariables = {
    EZA_COLORS = "di=34;1:mp=34;1:bu=33;1:cm=90";
  };
}
