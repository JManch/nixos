{ pkgs }:
{
  home.packages = with pkgs; [
    discord
    # Waiting for https://github.com/Vencord/Vesktop/pull/1198
    # (vesktop.override { withMiddleClickScroll = true; })
  ];

  ns.desktop.hyprland.settings.windowrule = [
    "match:class vesktop|discord, workspace special:scratch3 silent"
  ];

  # Electron apps core dump on exit with the default KillMode control-group.
  # This causes compositor exit to get delayed so just aggressively kill
  # these apps with Killmode mixed.
  ns.desktop.uwsm.appUnitOverrides = {
    "vesktop@.service" = ''
      [Service]
      KillMode=mixed
    '';

    "discord@.service" = ''
      [Service]
      # discord spams "The resource..." logs
      StandardOutput=null
      KillMode=mixed
    '';
  };

  ns.persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
