{
  lib,
  pkgs,
  inputs,
  hostname,
}:
let
  inherit (lib) listToAttrs nameValuePair;
  inherit (inputs.nix-resources.secrets)
    fqDomain
    ircServerName
    ircUsername
    ircChannels
    ;

  notificationConfig = {
    show_toast = true;
    sound = "bloop";
    show_content = true;
  };
in
{
  home.packages = [ pkgs.halloy ];

  xdg.configFile."halloy/config.toml".source = (pkgs.formats.toml { }).generate "halloy-config" (
    {
      scale_factor = 1.5;

      servers.${ircServerName} = {
        nickname = ircUsername;
        server = "irc.${fqDomain}";
        channels = ircChannels;
        order_channels_by = "config";
        sasl.plain = {
          username = "${ircUsername}@${hostname}";
          password_file = "/run/user/1000/agenix/ircPassword";
        };
      };

      filehost.enabled = true;

      actions.sidebar = {
        buffer = "new-pane";
        channel = "replace-pane";
        query = "new-pane";
      };

      preview.card.hide_url = "contains-only-url";

      buffer.text_input = {
        max_lines = 999999;
        auto_format = "markdown";
      };

      buffer.commands.exec.enabled = true;

      notifications = {
        direct_message = notificationConfig;
        highlight = notificationConfig;
        monitored_online = notificationConfig;
        monitored_offline = notificationConfig;
      };

      keyboard = {
        move_up = "ctrl+k";
        move_down = "ctrl+j";
        move_left = "ctrl+h";
        move_right = "ctrl+l";
        command_bar = "alt+space";
        new_horizontal_buffer = "alt+x";
        new_vertical_buffer = "alt+v";
        maximize_buffer = "ctrl+e";
        close_buffer = "ctrl+w";
        restore_buffer = "ctrl+shift+t";
        scroll_up_page = "ctrl+u";
        scroll_down_page = "ctrl+d";
        scroll_to_bottom = "ctrl+shift+g";
        leave_buffer = "alt+shift+w";
        toggle_sidebar = "alt+b";
        toggle_nick_list = "alt+n";
        toggle_fullscreen = "none";
        logs = "none";
        file_transfers = "none";
        reload_configuration = "ctrl+r";
        theme_editor = "none";
        highlights = "alt+h";
      };
    }
    // {
      notifications.channel = listToAttrs (map (c: nameValuePair c notificationConfig) ircChannels);
    }
  );

  ns.desktop.hyprland.settings.windowrule = [
    "match:class org\\.squidowl\\.halloy, workspace special:scratch3 silent"
    "match:class org\\.squidowl\\.halloy, suppress_event maximize"
  ];

  ns.persistence.directories = [ ".local/share/halloy" ];
}
