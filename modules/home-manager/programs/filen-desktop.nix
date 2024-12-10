{
  lib,
  config,
  selfPkgs,
  ...
}:
let
  cfg = config.${lib.ns}.programs.filenDesktop;
in
lib.mkIf cfg.enable {
  home.packages = [ selfPkgs.filen-desktop ];

  desktop.hyprland.settings.windowrulev2 = [
    "nomaxsize, class:^(filen-desktop)$"
    # The progress window instantly closes as soon as it loses focus
    "stayfocused, class:^(filen-desktop)$"
  ];

  persistence.directories = [ ".config/filen-desktop" ];
}
