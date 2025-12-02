{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    singleton
    optionalString
    getExe'
    ;
  inherit (config.${ns}.core) device;
  inherit (config.${ns}.system) impermanence;
in
[
  {
    enableOpt = false;

    opts.coordinates = with lib; {
      latitude = mkOption {
        type = types.number;
        default = 50.8;
        description = ''
          Default latitude of the host. Can be imperatively modified with the
          `modify-timezone` command.
        '';
      };

      longitude = mkOption {
        type = types.number;
        default = -0.1;
        description = ''
          Default longitude of the host. Can be imperatively modified with the
          `modify-timezone` command.
        '';
      };
    };

    # On laptops we would rather set timezone imperatively with `timedatectl` for
    # when we are away from home
    time.timeZone = if device.type == "laptop" then null else "Europe/London";

    system.activationScripts."setup-coordinates" =
      let
        # Activation runs in initrd before impermanence bind mounts so we need
        # to use persist path
        coordsDir = lib.${ns}.impermanencePrefix config "/etc/coordinates";
      in
      # bash
      ''
        mkdir -p ${coordsDir}
        if [ ! -f "${coordsDir}/latitude" ]; then
          echo -n "${toString cfg.coordinates.latitude}" > "${coordsDir}/latitude"
          chown 644 "${coordsDir}/latitude"
        fi

        if [ ! -f "${coordsDir}/longitude" ]; then
          echo -n "${toString cfg.coordinates.longitude}" > "${coordsDir}/longitude"
          chown 644 "${coordsDir}/longitude"
        fi
      '';

    environment.systemPackages = singleton (
      pkgs.writeShellApplication {
        name = "modify-timezone";
        runtimeInputs = with pkgs; [ systemd ];
        text = ''
          if [[ $(id -u) != "0" ]]; then
             echo "This script must be run as root" >&2
             exit 1
          fi

          ${optionalString (config.time.timeZone == null) ''
            timedatectl list-timezones --no-pager
            timedatectl status
            read -p "Enter one of the above timezones (leave blank to not modify): " -r timezone

            if [[ -n $timezone ]]; then
              timedatectl set-timezone "$timezone"
            fi
          ''}

          function set_coord() {
            while true; do
              current="unset"
              if [[ -f "/etc/coordinates/$1" ]]; then
                current="$(</etc/coordinates/"$1")"
              fi

              [[ $1 == "latitude" ]] && default="${toString cfg.coordinates.latitude}" || default="${toString cfg.coordinates.longitude}"

              read -p "Enter $1 (config default is '$default'. Leave blank to keep as '$current'): " -r coord
              if [[ -z $coord ]]; then
                return 0
              fi

              if [[ $coord =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?$ ]]; then
                echo -n "$coord" > "/etc/coordinates/$1"
                chown 644 "/etc/coordinates/$1"
                return 0
              else
                echo "Invalid coordinate, please try again."
              fi
            done
          }

          set_coord "latitude"
          set_coord "longitude"
        '';
      }

    );

    ns.persistence.directories = [ "/etc/coordinates" ];
  }

  (mkIf (impermanence.enable && config.time.timeZone == null) {
    # Ugly persistence implementation due to https://github.com/nix-community/impermanence/issues/153
    system.activationScripts."setup-localtime" = # bash
      ''
        if [ ! -e "/etc/localtime" ] && [ -L "/persist/etc/localtime" ]; then
          cp -d /persist/etc/localtime /etc/localtime
        fi
      '';

    systemd.services."persist-localtime" = {
      description = "Persist /etc/localtime";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${getExe' pkgs.coreutils "cp"} -d /etc/localtime /persist/etc/localtime";
      };
      wantedBy = [ "multi-user.target" ];
    };
  })
]
