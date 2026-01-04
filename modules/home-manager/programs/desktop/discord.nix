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
    # Waiting for https://github.com/Vencord/Vesktop/pull/1198
    # (vesktop.override { withMiddleClickScroll = true; })
  ];

  ns.desktop.hyprland.settings = {
    workspace = [
      "special:discord, gapsin:${toString (style.gapSize * 2)}, gapsout:${toString (style.gapSize * 4)}"
    ];

    windowrule = [
      "match:class vesktop|discord, workspace special:discord silent"
    ];

    bind = [
      "${hyprland.modKey}, D, togglespecialworkspace, discord"
      "${hyprland.modKey}SHIFT, D, movetoworkspacesilent, special:discord"
    ];

    gesture = [ "3, down, special, discord" ];
  };

  # Electron apps core dump on exit with the default KillMode control-group.
  # This causes compositor exit to get delayed so just aggressively kill
  # these apps with Killmode mixed.
  ns.desktop.uwsm.appUnitOverrides = lib.genAttrs [ "vesktop@.service" "discord@.service" ] (_: ''
    [Service]
    KillMode=mixed
  '');

  ns.persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
