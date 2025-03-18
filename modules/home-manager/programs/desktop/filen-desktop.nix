{ selfPkgs }:
{
  home.packages = [ selfPkgs.filen-desktop ];

  ns.desktop.hyprland.settings.windowrule = [
    "nomaxsize, class:^(filen-desktop)$"
    # The progress window instantly closes as soon as it loses focus
    "stayfocused, class:^(filen-desktop)$"
  ];

  ns.persistence.directories = [ ".config/filen-desktop" ];
}
