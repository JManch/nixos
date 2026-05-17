{
  lib,
  pkgs,
  inputs,
}:
let
  inherit (lib) listToAttrs nameValuePair;
  inherit (inputs.nix-resources.secrets)
    fqDomain
    ircServerName
    ircUsername
    ircChannels
    ;
in
{
  home.packages = [ pkgs.halloy ];

  xdg.configFile."halloy/config.toml".source =
    (pkgs.formats.toml { }).generate "halloy-config" {
      scale_factor = 1.5;

      servers.${ircServerName} = {
        nickname = ircUsername;
        server = "irc.${fqDomain}";
        channels = ircChannels;
        sasl.plain = {
          username = ircUsername;
          password = "test";
        };
      };

      filehost.enabled = true;

      actions.sidebar = {
        buffer = "new-pane";
        channel = "replace-pane";
        query = "new-pane";
        focused_buffer = "close_pane";
      };

      preview.card.hide_url = "contains-only-url";

      buffer.text_input = {
        max_lines = 999999;
        auto_format = "markdown";
      };
    }
    // {
      notifications.channel = listToAttrs (
        map (
          c:
          nameValuePair c {
            show_toast = true;
            sound = "bloop";
            show_content = true;
          }
        ) ircChannels
      );
    };

  ns.persistence.directories = [ ".local/share/halloy" ];
}
