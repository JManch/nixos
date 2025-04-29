{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns;
  inherit (config.${ns}.desktop) style hyprland;
in
{
  home.packages = with pkgs; [
    discord
    (vesktop.override { withMiddleClickScroll = true; })
  ];

  ns.desktop.hyprland.settings = {
    workspace = [
      "special:discord, gapsin:${toString (style.gapSize * 2)}, gapsout:${toString (style.gapSize * 4)}"
    ];

    windowrule = [
      "workspace special:discord silent, class:^(vesktop|discord)$, title:^(Discord.*)$"
    ];

    bind = [
      "${hyprland.modKey}, D, togglespecialworkspace, discord"
      "${hyprland.modKey}SHIFT, D, movetoworkspacesilent, special:discord"
    ];
  };

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
