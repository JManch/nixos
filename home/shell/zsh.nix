{ config, lib, pkgs, ... }:

{
  # TODO: Enable fzf zsh support in fzf module
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
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
    completionInit = "autoload -U compinit -d ${config.xdg.cacheHome}/zsh/zcompdump-$ZSH_VERSION && compinit";
    history = {
      path = "${config.xdg.stateHome}/zsh/zsh_history";
      extended = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
    };
    shellAliases = {
      reload = "exec zsh";
      rebuild-home = "home-manager switch --flake ~/.config/nixos#joshua";
    };
    initExtra = /* bash */ ''
      setopt interactivecomments
    '';
  };
}
