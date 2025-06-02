{
  lib,
  pkgs,
  config,
}:
{
  programs.git = {
    enable = true;
    userEmail = "JManch@protonmail.com";
    userName = "Joshua Manchester";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      gpg.format = "ssh";
      sendemail = {
        # Protonmail is bad for sending git patches so use gmail for this.
        # Remember to use correct email in commit author attribute.

        # To setup in a repo:
        # `git config user.email <gmail_email>`
        # `git config user.smptuser <gmail_email>`
        # `git config sendemail.smtpPass <gmail_smtp_pass>`
        smtpserver = "smtp.gmail.com";
        smtpencryption = "tls";
        smtpserverport = 587;
      };
    };

    signing = {
      key = "${config.home.homeDirectory}/.ssh/id_ed25519";
      signByDefault = true;
    };
  };

  # To disable the circles in the commit view hit <C-l> and set "show git
  # graph" to "when maximised". For some reason lazygit is forcing stateful
  # config.
  programs.lazygit = {
    enable = true;
    settings.git.overrideGpg = true;
  };

  programs.zsh = {
    shellAliases = {
      lg = "lazygit";
    };

    initContent = # bash
      ''
        lazygit() {
          ${lib.${lib.ns}.sshAddQuiet pkgs}
          command lazygit "$@"
        }
      '';
  };

  ns.persistence.directories = [ ".local/state/lazygit" ];
}
