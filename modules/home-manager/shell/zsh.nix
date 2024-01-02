{ lib
, config
, username
, pkgs
, ...
}:
lib.mkIf config.modules.shell.enable {
  home.packages = with pkgs; [
    fd
    bat
  ];

  home.sessionVariables = {
    COLORTERM = "truecolor";
  };

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
    # TODO: Fix this, .zcompdump is going to .config/zsh/.zcompdump instead
    completionInit = "autoload -U compinit -d ${config.xdg.cacheHome}/zsh/zcompdump-$ZSH_VERSION && compinit";
    history = {
      path = "${config.xdg.stateHome}/zsh/zsh_history";
      extended = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
    };
    shellAliases = {
      reload = "exec ${config.programs.zsh.package}/bin/zsh";
      rebuild-home = "home-manager switch --flake ~/.config/nixos#${username}";
    };
    initExtra = /* bash */ ''
      setopt interactivecomments

      reboot () {
        read -q "REPLY?Are you sure you want to reboot? (y/n)"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          ${pkgs.systemd}/bin/reboot
        fi
      }
    '';
  };
}
