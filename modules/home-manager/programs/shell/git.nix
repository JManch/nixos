{
  lib,
  pkgs,
  config,
}:
{
  programs.git = {
    enable = true;

    settings = {
      user.email = "JManch@protonmail.com";
      user.name = "Joshua Manchester";
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
  home.packages = [
    (pkgs.symlinkJoin {
      name = "lazygit-wrapped";
      paths = [ pkgs.lazygit ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      # WARN: The --use-config-file flag overrides the default lazygit config
      # so keep this in mind if I want to change any other lazygit settings in
      # the future
      postBuild = ''
        wrapProgram $out/bin/${pkgs.lazygit.meta.mainProgram} --run '
          # If we are NOT in an SSH session override lazygit config to enable overrideGpg. 
          # Doing this because overrideGpg causes commit signing to hang over
          # SSH as the SSH passphrase prompts breaks. I do not want to disable
          # overrideGpg all the time because it causes the lazygit window to
          # temporarily close everytime we make a commit.
          if [[ -z $SSH_CONNECTION && -z $SSH_CLIENT && -z $SSH_TTY ]]; then
            exec ${lib.getExe pkgs.lazygit} --use-config-file ${pkgs.writeText "lazygit-override-gpg-config" ''
              git:
                overrideGpg: true
            ''} "$@"
          fi
        '
      '';
    })
  ];

  # Lazygit config for usable performance in large repos e.g. nixpkgs
  # https://github.com/NixOS/nixpkgs/issues/423262#issuecomment-3053002428
  # Copy this file to the local repo in .git/lazygit.yml
  xdg.configFile."lazygit/large-repo.yml".text = # yaml
    ''
      git:
        branchLogCmd: git log --color=always --abbrev-commit --decorate --date=relative --pretty=medium {{branchName}} --
        allBranchesLogCmds:
          - git log --all --color=always --abbrev-commit --decorate --date=relative  --pretty=medium
        log:
          order: default
    '';

  programs.zsh.shellAliases.lg = "lazygit";

  ns.persistence.directories = [ ".local/state/lazygit" ];
}
