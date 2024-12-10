{ lib, config, ... }:
lib.mkIf config.${lib.ns}.shell.enable {
  programs.zellij = {
    enable = true;
    # TODO: Configure this
    # Waiting for better theming
    # https://github.com/zellij-org/zellij/issues/2297
    # https://github.com/zellij-org/zellij/pull/3242
  };
}
