{ lib, pkgs }:
{
  home.packages = with pkgs; [
    discord
    (vesktop.override { withMiddleClickScroll = true; })
  ];

  ns.desktop.hyprland.settings.windowrule = [
    "workspace special:social silent, class:^(vesktop|discord)$, title:^(Discord.*)$"
  ];

  # Electron apps core dump on exit with the default KillMode control-group.
  # This causes compositor exit to get delayed so just aggressively kill
  # these apps with Killmode mixed.
  ns.desktop.uwsm.appUnitOverrides = lib.genAttrs [ "vesktop-.scope" "discord-.scope" ] (_: ''
    [Scope]
    KillMode=mixed
  '');

  ns.persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
