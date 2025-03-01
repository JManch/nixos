{ lib, pkgs }:
{
  home.packages = with pkgs; [
    discord
    (vesktop.override { withMiddleClickScroll = true; })
  ];

  desktop.hyprland.settings.windowrulev2 = [
    "workspace special:social silent, class:^(vesktop|discord)$, title:^(Discord.*)$"
  ];

  ns = {
    # Electron apps core dump on exit with the default KillMode control-group.
    # This causes compositor exit to get delayed so just aggressively kill
    # these apps with Killmode mixed.
    desktop.uwsm.appUnitOverrides = lib.genAttrs [ "vesktop-.scope" "discord-.scope" ] (_: ''
      [Scope]
      KillMode=mixed
    '');

    persistence.directories = [
      ".config/discord"
      ".config/vesktop"
    ];
  };
}
