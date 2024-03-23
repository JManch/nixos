{ lib, config, ... }:
lib.mkIf config.modules.shell.enable
{
  programs.zellij = {
    enable = true;
    # TODO: Configure this
    settings = {
      # pane_frames = false;
    };
  };
}
