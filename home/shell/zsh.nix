{ config, lib, pkgs, ... }:

{
  # TODO: Enable fzf zsh support in fzf module
  programs.zsh = {
    enable = true;
    syntaxHighlighting = {
      enable = true;
      styles = {
        path = "none";
        path_prefix = "none";
        unknown-token = "fg=red";
        precommand = "fg=green";
      };
    };
    enableAutosuggestions = true;
    enableCompletion = true;
    history = {
      extended = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
    };
    shellAliases = {
      reload = "exec zsh";
      rebuild-home = "home-manager switch --flake ~/.config/nixos#joshua";
    };
  };
}
