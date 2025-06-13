{
  lib,
  cfg,
  pkgs,
  config,
  hostname,
  selfPkgs,
  username,
  categoryCfg,
}:
let
  inherit (lib)
    ns
    mkOption
    mkPackageOption
    all
    types
    length
    optionalString
    attrNames
    mkIf
    removePrefix
    elemAt
    flatten
    imap0
    attrValues
    getExe
    genAttrs
    any
    mapAttrs'
    mapAttrsToList
    nameValuePair
    concatMapStringsSep
    filterAttrs
    ;
  inherit (config.${ns}.system) impermanence;
  backups = filterAttrs (_: backup: backup.backend == "rclone") categoryCfg.backups;
in
[
  {
    guardType = "first";

    opts = {
      remotes = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                # Just used to determine whether the remote config secret should
                # be added to this host
                enable = mkOption {
                  type = types.bool;
                  internal = true;
                  default = cfg.enable && (any (backup: backup.backendOptions.remote == name) (attrValues backups));
                };

                package = mkPackageOption pkgs "rclone" { };

                timerConfig = mkOption {
                  type = with types; nullOr attrs;
                  default = {
                    OnCalendar = "daily";
                    Persistent = true;
                  };
                  description = ''
                    Default timer config for backups using the Rclone backend.
                  '';
                };

                root = mkOption {
                  type = types.str;
                  default = "nixos-backups/${hostname}";
                  description = ''
                    Root remote path that all backups are stored under.
                  '';
                };

                setupScript = mkOption {
                  type = types.lines;
                  default = ''
                    rclone --config "$config_dir" config create "${name}-remote" "${name}" --all
                  '';
                  description = ''
                    Script for generating the rclone config.
                  '';
                };
              };
            }
          )
        );
        default = {
          proton = { };
          filen = {
            package = selfPkgs.filen-rclone;
            setupScript = # bash
              ''
                ${getExe pkgs.filen-cli} export-api-key
                rm -rf /root/.config/{@filen,filen-cli}
                read -p -r "Enter the API key above: " api_key
                rclone --config "$config_dir/config" config create "filen-remote" "filen" "api_key=$api_key" --all --obscure
              '';
          };
        };
        description = ''
          Attribute set of remotes where the name matches the rclone 'storage'
          config key.
        '';
      };

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 17:30:00";
        description = "When to run backups in systemd OnCalendar format";
      };

      destinationRoot = mkOption {
        type = types.str;
        default = "";
      };
    };

    asserts = flatten (
      mapAttrsToList (name: backup: [
        (
          (length (attrNames backup.backendOptions.remotePaths) == length backup.paths)
          && (all (v: v == true) (
            imap0 (i: path: (elemAt backup.paths i) == path) (attrNames backup.backendOptions.remotePaths)
          ))
        )
        "Rclone backup ${name} has not declared a remote path for all `paths` in `remotePaths`"
      ]) backups
    );

    ns.userPackages = mapAttrsToList (
      name: value:
      pkgs.writeShellApplication {
        name = "rclone-setup-${name}";
        runtimeInputs = [ value.package ];
        text = ''
          config_dir=$(mktemp -d)
          chmod 700 "$config_dir"
          ${value.setupScript}
          echo "Saved rclone config to $config_dir/config"

          while :; do
            read -r -p "Enter path to nix-resources repo: " nix_resources
            if [[ -f "$nix_resources/flake.nix" ]]; then
              break
            else
              echo "Error: '$nix_resources' is not a valid path (flake.nix not found)" >&2
            fi
          done

          EDITOR="cp /dev/stdin" agenix-edit "$nix_resources/secrets/rclone-${name}-config.age" < "$config_dir/config"
          rm -rf "$config_dir"
        '';
      }
    ) cfg.remotes;

    systemd.services = mapAttrs' (
      name: backup:
      nameValuePair "rclone-backups-${name}" {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            let
              remoteCfg = cfg.remotes.${backup.backendOptions.remote};
              remoteConfig = config.age.secrets."rclone-${backup.backendOptions.remote}-config".path;
            in
            pkgs.writeShellApplication {
              name = "rclone-backups-${name}";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.diffutils
                remoteCfg.package
              ];
              text = ''
                ${concatMapStringsSep "\n  " (path: ''
                  if [[ ! -e "${path}" ]]; then
                    echo "Error: Backup path '${path}' does not exist" >&2
                    exit 1
                  fi
                '') backup.paths}

                # Abort if network is down as rclone authentication will break and needs manual
                # intervention to fix
                if ! wget -q --spider http://google.com; then
                  echo "Error: Internet connection cannot be established, aborting backup" >&2
                  exit 1
                fi

                if [[ ! -f "$CACHE_DIRECTORY/config" ]] || ! cmp -s "$CACHE_DIRECTORY/config" "${remoteConfig}"; then
                  cp "${remoteConfig}" "$CACHE_DIRECTORY/config"
                  cp "${remoteConfig}" "$CACHE_DIRECTORY/config-original"
                fi

                ${concatMapStringsSep "\n  " (
                  path:
                  ''rclone --config "$CACHE_DIRECTORY/config" ${backup.backendOptions.mode} "${path}" "remote:${removePrefix "/" remoteCfg.root}/${
                    removePrefix "/" backup.backendOptions.remotePaths.${path}
                  }"''
                ) backup.paths}
              '';
            };

          # Writeable config is stored in cache directory
          CacheDirectory = "rclone-backups-${name}";
          CacheDirectoryMode = "0700";
          PrivateTmp = true;
          TimeoutStartSec = mkIf (backup.backendOptions.timeout != null) backup.backendOptions.timeout;
        };
      }
    ) backups;

    systemd.timers = mapAttrs' (
      name: backup:
      nameValuePair "rclone-backups-${name}" {
        wantedBy = [ "timers.target" ];
        inherit (backup) timerConfig;
      }
    ) (filterAttrs (_: backup: backup.timerConfig != null) backups);

    ns.persistence.directories = mapAttrsToList (name: _: {
      directory = "/var/cache/rclone-backups-${name}";
      mode = "0700";
    }) backups;
  }

  {
    ns.services.backups.backends.rclone = args: {
      options = {
        remote = mkOption {
          type = types.enum (attrNames cfg.remotes);
          description = "Remote cloud to backup to";
        };

        remotePaths = mkOption {
          type = with types; attrsOf str;
          # default = genAttrs backups.${args.backupName}.paths (path: path);
          default = genAttrs args.backupConfig.paths (path: path);
          apply = mapAttrs' (
            name: value:
            nameValuePair (
              optionalString impermanence.enable "/persist"
              + optionalString args.backupConfig.isHome "/home/${username}/"
              + name
            ) value
          );
          description = ''
            Attribute set of paths and their remote backup paths relative to the
            remote's `destinationRoot`. If defined, the remote path of every
            backup path must be declared.
          '';
        };

        mode = mkOption {
          type = types.enum [
            "sync"
            "copy"
          ];
          description = "Rclone backup mode";
        };

        timeout = mkOption {
          type = with types; nullOr int;
          default = null;
          example = 120;
          description = ''
            Sometimes rclone backups of small files get take an abnormally long time if the
            remote directory has lots of files. The fix is to move the remote backup dir
            and save new backups to an empty one.

            Timeout is the number of seconds after which the service should fail and notify
            us. This way we know when the remote dir needs changing. Only makes sense for
            small backups that should not take very long.
          '';
        };
      };
    };
  }
]
