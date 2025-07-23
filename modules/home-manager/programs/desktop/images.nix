{
  lib,
  pkgs,
  config,
}:
let
  inherit (config.${lib.ns}) desktop;
in
{
  home.packages = with pkgs; [
    swayimg
    gthumb # image editor
  ];

  xdg.configFile."swayimg/config".source = (pkgs.formats.ini { }).generate "config" {
    general.compositor = false;
    font.name = desktop.style.font.family;

    "keys.viewer" = {
      Left = "prev_file";
      Right = "next_file";
      f = "fullscreen";
      plus = "zoom +10";
      underscore = "zoom -10";
      ScrollUp = "zoom +5";
      ScrollDown = "zoom -5";
      r = "zoom optimal";
      less = "rotate_left";
      greater = "rotate_right";
      x = "flip_vertical";
      z = "flip_horizontal";
      "Ctrl+r" = "reload";
      i = "info viewer";
      q = "exit";
      question = "help";
    };
  };

  programs.zsh.shellAliases = {
    img = "swayimg";
    img-edit = "gthumb";
    screenshot-edit = "gthumb ${config.xdg.userDirs.pictures}/screenshots/*(.om[1])";
  };

  xdg.mimeApps.defaultApplications = lib.listToAttrs (
    map
      (type: {
        name = "image/${type}";
        value = [ "swayimg.desktop" ];
      })
      [
        "gif"
        "png"
        "jpeg"
        "webp"
      ]
  );
}
