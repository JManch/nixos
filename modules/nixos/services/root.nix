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
    mkMerge
    mapAttrsToList
    mkIf
    optionalString
    mkAfter
    mapAttrs
    replaceStrings
    toUpper
    getExe
    mkOption
    mkEnableOption
    ;
  inherit (config.${ns}.core) device;

  mkLaptopPowerTarget = type: {
    description = "On ${type} Power";
    conflicts = [ (if type == "AC" then "battery.target" else "ac.target") ];
    unitConfig = {
      DefaultDependencies = false;
      StopWhenUnneeded = true;
    };
  };

  notifyServiceSubmodule =
    type:
    types.submodule (
      { name, config, ... }:
      {
        options = {
          title = mkOption {
            type = types.str;
            default = "${replaceStrings [ "-" ] [ " " ] (lib.${ns}.upperFirstChar name)} ${
              if type == "success" then "succeeded" else "failed"
            }";
            description = "Message title";
          };

          contents = mkOption {
            type = types.str;
            default = "${config.title} on host ${hostname}";
            description = "Message contents";
          };

          contentsScript = mkOption {
            type = with types; nullOr str;
            default = null;
            description = "Single line script that prints message content to stdout. Replaces the contents option.";
          };

          email.enable = mkEnableOption "sending a ${type} email" // {
            default = true;
          };

          discord = {
            enable = mkEnableOption "sending a discord ${type} message";

            var = mkOption {
              type = types.str;
              example = "RESTIC";
              description = "The _(FAILURE|SUCCESS)_DISCORD_AUTH variable prefix";
            };
          };
        };
      }
    );
in
{
  opts = {
    successNotifyServices = mkOption {
      type = types.attrsOf (notifyServiceSubmodule "success");
      default = { };
      description = ''
        Attribute set of success notification services where the attribute
        name matches the service that should trigger the success service.
      '';
    };

    failureNotifyServices = mkOption {
      type = types.attrsOf (notifyServiceSubmodule "failure");
      default = { };
      description = ''
        Attribute set of failure notification services where the attribute
        name matches the service that should trigger the failure service.
      '';
    };

    healthCheckServices = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options.var = mkOption {
              type = types.str;
              default = replaceStrings [ "-" ] [ "_" ] (toUpper name);
              description = ''
                Name of the variable inside the health checks secret file that contains the
                health check endpoint.
              '';
            };
          }
        )
      );
      default = { };
      description = ''
        Attribute set of services that should use ping healthchecks.io when the
        successfully complete. The name must match the service name exactly.
      '';
    };
  };

  asserts = [
    ((cfg.failureNotifyServices != { }) -> config.age.secrets ? notifyVars)
    "Failure notify services require the notifyVars secret"
    ((cfg.healthCheckServices != { }) -> config.age.secrets ? healthCheckVars)
    "Heath check services require the healthCheckVars secret"
  ];

  # Allows user services like home-manager syncthing to start on boot and
  # keep running rather than stopping and starting with each ssh session on
  # servers
  users.users.${username}.linger = config.${ns}.core.device.type == "server";

  systemd.services =
    let
      mkNotifyServices =
        type:
        mapAttrsToList (name: value: {
          "${name}-${type}-notify" = {
            restartIfChanged = false;
            serviceConfig = {
              Type = "oneshot";
              EnvironmentFile = config.age.secrets.notifyVars.path;
              ExecStart = getExe (
                pkgs.writeShellApplication {
                  name = "${name}-${type}-notify";
                  runtimeInputs = [ pkgs.shoutrrr ];
                  text =
                    optionalString value.discord.enable ''
                      shoutrrr send \
                        --url "discord://${"$" + value.discord.var}_${toUpper type}_DISCORD_AUTH" \
                        --title "${value.title}" \
                        --message "${
                          if value.contentsScript == null then value.contents else "$(${value.contentsScript})"
                        }"
                    ''
                    + optionalString value.email.enable ''
                      shoutrrr send \
                        --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=${
                          replaceStrings [ " " ] [ "%20" ] value.title
                        }" \
                        --message "${
                          if value.contentsScript == null then value.contents else "$(${value.contentsScript})"
                        }"
                    '';
                }
              );
            };
          };

          ${name}."on${lib.${ns}.upperFirstChar type}" = [ "${name}-${type}-notify.service" ];
        }) cfg."${type}NotifyServices";
    in
    mkMerge (
      mkNotifyServices "failure"
      ++ mkNotifyServices "success"
      ++ [
        (mapAttrs (name: value: {
          serviceConfig.ExecStartPost = mkAfter [
            (getExe (
              pkgs.writeShellApplication {
                name = "${name}-send-health-check";
                runtimeInputs = [ pkgs.curl ];
                text = ''
                  # shellcheck source=/dev/null
                  source ${config.age.secrets.healthCheckVars.path}
                  curl -s "${"$" + value.var}"
                '';
              }
            ))
          ];
        }) cfg.healthCheckServices)
      ]
    );

  services.udev.extraRules = mkIf (device.type == "laptop") ''
    SUBSYSTEM=="power_supply", KERNEL=="${device.ac}", ATTR{online}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}="battery.target", ENV{SYSTEMD_USER_WANTS}="battery.target"
    SUBSYSTEM=="power_supply", KERNEL=="${device.ac}", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="ac.target", ENV{SYSTEMD_USER_WANTS}="ac.target"
  '';

  systemd.targets = mkIf (device.type == "laptop") {
    ac = mkLaptopPowerTarget "AC";
    battery = mkLaptopPowerTarget "Battery";
  };

  systemd.user.targets = mkIf (device.type == "laptop") {
    ac = mkLaptopPowerTarget "AC";
    battery = mkLaptopPowerTarget "Battery";
  };
}
