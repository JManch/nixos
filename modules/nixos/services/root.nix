{
  lib,
  cfg,
  pkgs,
  config,
  username,
  hostname,
}:
let
  inherit (lib)
    ns
    types
    mapAttrs'
    optionalString
    nameValuePair
    mapAttrs
    replaceStrings
    getExe
    mkOption
    mkEnableOption
    ;
in
{
  opts.failureNotifyServices = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        {
          options = {
            title = mkOption {
              type = types.str;
              default = "${replaceStrings [ "-" ] [ " " ] (lib.${ns}.upperFirstChar name)} failed";
              description = "Message title";
            };

            contents = mkOption {
              type = types.str;
              default = "${config.title} on host ${hostname}";
              description = "Message contents";
            };

            email.enable = mkEnableOption "sending a failure email" // {
              default = true;
            };

            discord = {
              enable = mkEnableOption "sending a discord failure message";

              var = mkOption {
                type = types.str;
                example = "RESTIC";
                description = "The *_DISCORD_AUTH variable prefix";
              };
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Attribute set of failure notification services to where the attribute
      name matches the service that should trigger the failure service.
    '';
  };

  asserts = [
    ((cfg.failureNotifyServices != { }) -> config.age.secrets ? notifVars)
    "Failure notif services require the notifVars secret"
  ];

  # Allows user services like home-manager syncthing to start on boot and
  # keep running rather than stopping and starting with each ssh session on
  # servers
  users.users.${username}.linger = config.${ns}.core.device.type == "server";

  systemd.services =
    (mapAttrs' (
      name: value:
      nameValuePair "${name}-failure-notify" {
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.age.secrets.notifVars.path;
          ExecStart = getExe (
            pkgs.writeShellApplication {
              name = "${name}-failure-notify";
              runtimeInputs = [ pkgs.shoutrrr ];
              text =
                optionalString value.discord.enable ''
                  shoutrrr send \
                    --url "discord://${"$" + value.discord.var}_DISCORD_AUTH" \
                    --title "${value.title}" \
                    --message "${value.contents}"
                ''
                + optionalString value.email.enable ''
                  shoutrrr send \
                    --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=${
                      replaceStrings [ " " ] [ "%20" ] value.title
                    }" \
                    --message "${name} failed on ${hostname}"
                '';
            }
          );
        };
      }
    ) cfg.failureNotifyServices)
    // mapAttrs (name: _: {
      onFailure = [ "${name}-failure-notify.service" ];
    }) cfg.failureNotifyServices;
}
