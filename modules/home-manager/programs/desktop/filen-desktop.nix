{ selfPkgs }:
{
  home.packages = [ selfPkgs.filen-desktop ];

  desktop.hyprland.settings.windowrulev2 = [
    "nomaxsize, class:^(filen-desktop)$"
    # The progress window instantly closes as soon as it loses focus
    "stayfocused, class:^(filen-desktop)$"
  ];

  ns.persistence.directories = [ ".config/filen-desktop" ];
}
