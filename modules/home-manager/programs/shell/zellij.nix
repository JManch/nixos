{
  enableOpt = false;

  programs.zellij = {
    enable = true;
    enableZshIntegration = false; # don't want autostart
    # TODO: Configure this
    # Waiting for better theming
    # https://github.com/zellij-org/zellij/issues/2297
    # https://github.com/zellij-org/zellij/pull/3242
  };
}
