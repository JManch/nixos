{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    escapeShellArg
    concatStringsSep
    concatMapStringsSep
    concatLines
    mkAfter
    optional
    genAttrs
    elem
    mapAttrsToList
    getExe
    mkForce
    singleton
    ;
  inherit (config.services.minecraft-server) dataDir;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy wireguard;
  inherit (caddy) allowAddresses trustedAddresses;
  cfg = config.modules.services.minecraft-server;
  serverPackage = pkgs.papermcServers.papermc-1_20_4;
  pluginEnabled = p: elem p cfg.plugins;

  availablePlugins =
    (import ../../../pkgs/minecraft-plugins { inherit lib pkgs; }).minecraft-plugins
    // inputs.nix-resources.packages.${pkgs.system}.minecraft-plugins;

  serverIcon = pkgs.fetchurl {
    url = "https://i.imgur.com/ugQk6xn.png";
    sha256 = "sha256-rU+Lg9EQGlSiXT5TQ7A7TITSwLRT5RpsbE3JdFDtot8=";
  };
in
mkIf cfg.enable {
  services.minecraft-server = {
    enable = true;
    openFirewall = false;
    declarative = true;
    eula = true;

    serverProperties = {
      gamemode = "survival";
      hardcore = false;
      level-name = "world";
      level-type = "minecraft:normal";
      motd = "NixOS Minecraft server";
      server-port = cfg.port - 1;
      pvp = true;
      generate-structures = true;
      max-chained-neighbor-updates = 1000000;
      difficulty = "hard";
      require-resource-pack = true;
      max-players = 5;
      enable-status = true;
      allow-flight = false;
      view-distance = 10;
      allow-nether = true;
      entity-broadcast-range-percentage = 100;
      simulation-distance = 10;
      player-idle-timeout = 5;
      white-list = false;
      log-ips = true;
      enforce-whitelist = false;
      spawn-protection = 0;
      # Instead of rcon use 'echo "mine <command>" > /run/minecraft-server.stdin' to
      # run commands on the server. Prefix commands with 'mine' to go through
      # msh and pass to the server.
      enable-rcon = false;
      # Msh uses queries
      enable-query = true;
      "query.port" = cfg.port - 1;
    };
  };

  modules.services.minecraft-server.mshConfig = {
    Server = {
      Folder = "${dataDir}";
      FileName = "minecraft-server";
    };
    Commands = {
      StartServer = concatStringsSep " " [
        "${getExe serverPackage}"
        "-Xmx${toString cfg.memory}M"
        "-Xms${toString cfg.memory}M"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:+PerfDisableSharedMem"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+UseG1GC"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1NewSizePercent=30"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:G1ReservePercent=20"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:MaxGCPauseMillis=200"
        "-XX:MaxTenuringThreshold=1"
        "-XX:SurvivorRatio=32"
        "-Dusing.aikars.flags=https://mcflags.emc.gs"
        "-Daikars.new.flags=true"
      ];
      StopServer = "stop";
      StopServerAllowKill = 30;
    };
    Msh = {
      Debug = 2;
      MshPort = cfg.port;
      MshPortQuery = cfg.port;
      EnableQuery = true;
      TimeBeforeStoppingEmptyServer = 3600;
      SuspendAllow = false;
      SuspendRefresh = -1;
      InfoHibernation = "                   §fserver status:\n                   §b§lHIBERNATING";
      InfoStarting = "                   §fserver status:\n                    §6§lWARMING UP";
      NotifyUpdate = false;
      NotifyMessage = true;
    };
  };

  modules.services.minecraft-server.files = mkMerge [
    {
      "spigot.yml".value = # yaml
        ''
          world-settings:
            default:
              entity-tracking-range:
                players: 128
                animals: 64
                monsters: 64
              merge-radius:
                exp: 0
                item: 0
        '';
    }

    (mkIf (pluginEnabled "aura-skills") {
      "plugins/AuraSkills/config.yml".value = # yaml
        ''
          on_death:
            reset_xp: true
        '';
    })

    (mkIf (pluginEnabled "vivecraft") {
      "plugins/Vivecraft-Spigot-Extensions/config.yml".value = # yaml
        ''
          bow:
            standingmultiplier: 1
            seatedheadshotmultiplier: 2
          welcomemsg:
            enabled: true
            welcomeVanilla: '&player has joined with non-VR!'
          crawling:
            enabled: true
          teleport:
            enable: false
        '';
    })

    (mkIf (pluginEnabled "squaremap") {
      "plugins/squaremap/config.yml".value = # yaml
        ''
          settings:
            web-address: https://squaremap.${fqDomain}
            internal-webserver:
              bind: 127.0.0.1
              port: 25566
        '';
    })

    # Some plugins need config to be applied in context of the default config.
    # To avoid copying the entire default config file into our nix config we
    # generate a diff and apply it to the reference config file sourced
    # upstream.
    (mkIf (pluginEnabled "levelled-mobs") {
      "plugins/LevelledMobs/rules.yml" = {
        reference = "${availablePlugins.levelled-mobs}/config/rules.yml";
        diff = ''
          --- rules.yml	2024-05-12 11:34:55.911349601 +0100
          +++ rules-custom.yml	2024-05-12 11:36:51.519976466 +0100
          @@ -426,11 +426,14 @@
           custom-rules:
             - enabled: true
               name: 'No Stat Change for Specific Entities'
          -    use-preset: vanilla_challenge, nametag_no_level
          +    use-preset: vanilla_challenge
               conditions:
                 entities:
                   allowed-groups: [ 'all_passive_mobs' ]
                   allowed-list: [ 'BABY_', 'WANDERING_TRADER', 'VILLAGER', 'ZOMBIE_VILLAGER', 'BAT' ]
          +    apply-settings:
          +      nametag: disabled
          +      nametag-visibility-method: DISABLED

             - enabled: true
               name: 'Custom Nether Levelling'
        '';
      };
    })
  ];

  systemd.services.minecraft-server = {
    path = [ pkgs.jre ]; # Msh needs java in path
    serviceConfig = {
      ExecStart = mkForce (getExe pkgs.minecraft-server-hibernation);
      # We don't need the graceful shutdown workaround because
      # minecraft-hibernate does it for us
      ExecStop = mkForce "";
    };
    preStart =
      # bash
      mkAfter ''
        # Msh setup
        install -m 640 "${cfg.mshConfig}" "${dataDir}/msh-config.json"
        ln -fs "${getExe serverPackage}" "${dataDir}/minecraft-server"
        ln -fs "${serverIcon}" "${dataDir}/server-icon-frozen.png"

        # Remove existing plugins
        readarray -d "" links < <(find "${dataDir}/plugins" -maxdepth 5 -type l -print0)
          for link in "''${links[@]}"; do
            if [[ "$(readlink "$link")" =~ ^${escapeShellArg builtins.storeDir} ]]; then
              rm "$link"
            fi
          done

        # Install new plugins
        mkdir -p plugins
        ${concatMapStringsSep "\n" (
          plugin: # bash
          ''
            ln -fs "${availablePlugins.${plugin}}"/*.jar "${dataDir}/plugins"
          '') cfg.plugins}

        # Install config files
        # We can't symlink from store because plugins need config write privs as
        # they merge our provided config with the default config
        ${concatLines (
          mapAttrsToList (
            path: file: # bash
            if file.value != null then
              ''
                rm -f "${dataDir}/${path}"
                install -m 640 -D "${pkgs.writeText "${baseNameOf path}" file.value}" "${dataDir}/${path}"
              ''
            else
              ''
                rm -f "${dataDir}/${path}"
                mkdir -p $(dirname "${path}")
                ${getExe pkgs.patch} -u "${file.reference}" "${pkgs.writeText "${baseNameOf path}.diff" file.diff}" -o "${dataDir}/${path}"
              ''
          ) cfg.files
        )}
      '';
  };

  services.caddy.virtualHosts = mkIf (pluginEnabled "squaremap") {
    "squaremap.${fqDomain}".extraConfig =
      let
        addressRange = toString wireguard.friends.address + "/" + toString wireguard.friends.subnet;
        wgAddresses = optional wireguard.friends.enable addressRange;
      in
      ''
        ${allowAddresses (trustedAddresses ++ wgAddresses)}
        reverse_proxy http://127.0.0.1:25566
        handle_errors {
          respond "Minecraft server is hibernating or offline" 503
        }
      '';
  };

  networking.firewall = {
    allowedTCPPorts = [ cfg.port ];
    allowedUDPPorts = [ cfg.port ];
  };

  # Open ports on additional interfaces
  networking.firewall.interfaces = (
    genAttrs cfg.interfaces (_: {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    })
  );

  backups.minecraft-server =
    let
      functions = # bash
        ''
          run_cmd_wait_for_message() {
              local found=false
              (sleep 5; echo "$1" > "/run/minecraft-server.stdin") &
              while read -r line; do
                  if [[ $line == *"$2"* ]]; then
                      found=true;
                      break;
                  fi
              done < <(timeout 30 journalctl -u minecraft-server -fqn0)
              echo $found
          }

          server_say() {
              echo "mine say $1" > "/run/minecraft-server.stdin"
              echo "$1"
          }
        '';

      preBackupScript = pkgs.writeShellApplication {
        name = "minecraft-server-pre-backup";
        runtimeInputs = with pkgs; [ coreutils ];
        text = # bash
          ''
            if [ ! -p "/run/minecraft-server.stdin" ]; then exit 0; fi

            ${functions}

            rm -f "/tmp/minecraft-server-save-off"
            server_running=$(run_cmd_wait_for_message "mine say Performing scheduled backup" "[Server] Performing scheduled backup")
            if $server_running; then
                server_say "Disabling auto-save..."
                if [ "$(run_cmd_wait_for_message "mine save-off" ": Automatic saving is now disabled")" == "false" ]; then
                    server_say "Failed to disable auto-save, aborting backup"
                    exit 1
                fi
                touch "/tmp/minecraft-server-save-off"
                sleep 10
                server_say "Auto-save disabled"

                server_say "Flushing pending disk writes..."
                if [ "$(run_cmd_wait_for_message "mine save-all" ": Saved the game")" == "false" ]; then
                    server_say "Failed to flush pending disk writes, aborting backup"
                    exit 1
                fi
                sleep 10
                server_say "Pending disk writes flushed"
                server_say "Performing backup..."
            fi
          '';
      };

      postBackupScript = pkgs.writeShellApplication {
        name = "minecraft-server-post-backup";
        runtimeInputs = with pkgs; [ coreutils ];
        text = # bash
          ''
            ${functions}
            if [ -e "/tmp/minecraft-server-save-off" ]; then
                server_say "Re-enabling auto-save..."
                if [ "$(run_cmd_wait_for_message "mine save-on" ": Automatic saving is now enabled")" == "false" ]; then
                    server_say "Failed to re-enable auto-save, reporting failure"
                    exit 1
                fi
                server_say "Auto-save re-enabled"
                server_say "Backup completed"
            fi
          '';
      };
    in
    {
      paths = [ "/var/lib/minecraft" ];
      exclude = [
        "cache"
        ".cache"
      ];

      preBackupScript = getExe preBackupScript;
      postBackupScript = getExe postBackupScript;

      restore = {
        preRestoreScript = ''
          sudo systemctl stop minecraft-server
        '';
        pathOwnership."/var/lib/minecraft" = {
          user = "minecraft";
          group = "minecraft";
        };
      };
    };

  persistence.directories = singleton {
    directory = "/var/lib/minecraft";
    user = "minecraft";
    group = "minecraft";
    mode = "755";
  };
}
