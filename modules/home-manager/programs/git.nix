{ lib, config, ... }:
let
  inherit (lib) mkIf getExe;
  cfg = config.modules.programs.git;
in
mkIf cfg.enable
{
  programs.git = {
    enable = true;
    userEmail = "JManch@protonmail.com";
    userName = "Joshua Manchester";

    extraConfig = {
      init.defaultBranch = "main";
      gpg.format = "ssh";
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

    initExtra = /*bash*/ ''
      lazygit() {
        ssh-add-quiet
        command ${getExe config.programs.lazygit.package} "$@"
      }
    '';
  };

  persistence.files = [
    ".config/lazygit/state.yml"
  ];
}
