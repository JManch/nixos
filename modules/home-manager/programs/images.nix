{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.programs.images;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    swayimg
    gthumb # image editor
  ];

  programs.zsh.shellAliases = {
    img = "swayimg";
    img-edit = "gthumb";
    screenshot-edit = "gthumb ${config.xdg.userDirs.pictures}/screenshots/*(.om[1])";
  };
}
