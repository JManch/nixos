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
    ((vesktop.override { withMiddleClickScroll = true; }).overrideAttrs {
      src =
        assert lib.assertMsg (
          pkgs.vesktop.version == "1.6.1"
        ) "Check if https://github.com/Vencord/Vesktop/pull/1198 has been merged into vesktop";
        fetchFromGitHub {
          owner = "T1mbits";
          repo = "Vesktop";
          rev = "b391beebaed859865523c95378e479d0da947190";
          hash = "sha256-O5ripbf/NW+MxJW6pfk5T+uQ3PqZ43+jCSgggbIpI94=";
        };
    })
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

    gesture = [ "3, down, special, discord" ];
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
