{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.images;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    feh # simple image viewer
    gthumb # image editor
  ];

  programs.zsh.shellAliases = {
    img = "feh";
    imgedit = "gthumb";
  };
}
