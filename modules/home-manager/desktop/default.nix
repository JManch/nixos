{ lib
, ...
}:
let
  inherit (lib) mkOption types;
in
{
  imports = [
    ./wayland
    ./gtk.nix
    ./font.nix
  ];
  options.modules.desktop = {
    sessionTarget = mkOption {
      type = types.str;
      default = "graphical-session.target";
      description = "The systemd target that will start desktop services";
    };
    cursorSize = mkOption {
      type = types.int;
      default = 24;
    };
    font = {
      family = mkOption {
        type = types.str;
        default = null;
        description = "Font family name";
        example = "Fira Code";
      };
      package = mkOption {
        type = types.package;
        default = null;
        description = "Font package";
        example = "pkgs.fira-code";
      };
    };
  };
}
