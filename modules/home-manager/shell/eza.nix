{ lib, config, ... }:
lib.mkIf config.modules.shell.enable {
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
    l = "ll"; # because nixpkgs creates an l alias by default
    ls = "eza";
    ll = "eza -l";
    lll = "ll -snew --group-directories-first";
    la = "eza -la";
    laa = "la -snew --group-directories-first";
  };

  home.sessionVariables = {
    EZA_COLORS = "di=34;1:mp=34;1:bu=33;1:cm=90";
  };
}
