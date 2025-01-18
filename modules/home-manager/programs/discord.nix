{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) ns mkIf genAttrs;
  cfg = config.${lib.ns}.programs.discord;
in
mkIf cfg.enable {
  home.packages = with pkgs; [
    discord
    (vesktop.override { withMiddleClickScroll = true; })
  ];

  desktop.hyprland.settings.windowrulev2 = [
    "workspace special:social silent, class:^(vesktop|discord)$, title:^(Discord.*)$"
  ];

  # Electron apps core dump on exit with the default KillMode control-group.
  # This causes compositor exit to get delayed so just aggressively kill
  # these apps with Killmode mixed.
  ${ns}.desktop.uwsm.appUnitOverrides = genAttrs [ "vesktop-.scope" "discord-.scope" ] (_: ''
    [Scope]
    KillMode=mixed
  '');

  persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
