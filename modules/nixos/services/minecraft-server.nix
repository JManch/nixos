{ lib
, pkgs
, config
, inputs
, outputs
, ...
}:
let
  inherit (lib) mkIf mkMerge escapeShellArg concatStringsSep mkAfter genAttrs elem mapAttrsToList getExe;
  inherit (config.services.minecraft-server) dataDir;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.minecraft-server;

  availablePlugins = outputs.packages.${pkgs.system}.minecraft-plugins;
  pluginEnabled = p: elem p cfg.plugins;
in
mkIf cfg.enable
{
  services.minecraft-server = {
    enable = true;
    openFirewall = true;
    package = pkgs.papermc.overrideAttrs (oldAttrs: {
      src = pkgs.fetchurl {
        url = "https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/496/downloads/paper-1.20.4-496.jar";
        hash = "sha256-nGQZw1BNuE1DfUu+tbnSfVSKAJo+0vHGF7Yuc0HP7uM=";
      };
    });
    jvmOpts = concatStringsSep " " [
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
    declarative = true;
    eula = true;

    serverProperties = {
      gamemode = "survival";
      hardcore = false;
      level-name = "world";
      level-type = "minecraft:normal";
      motd = "NixOS Minecraft server";
      server-port = cfg.port;
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
      player-idle-timeout = 0;
      white-list = false;
      log-ips = true;
      enforce-whitelist = false;
      spawn-protection = 0;
      # Instead of rcon use 'echo "command" > /run/minecraft-server.stdin' to
      # run commands on the server
      enable-rcon = false;
    };
  };

  modules.services.minecraft-server.files = mkMerge [
    (mkIf (pluginEnabled "aura-skills") {
      "plugins/AuraSkills/config.yml".value = /*yaml*/ ''
        on_death:
          reset_xp: true
      '';
    })

    (mkIf (pluginEnabled "vivecraft") {
      "plugins/Vivecraft-Spigot-Extensions/config.yml".value = /*yaml*/ ''
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
      "plugins/squaremap/config.yml".value = /*yaml*/ ''
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
          --- rules.yml   2024-05-11 15:43:44.818184123 +0100
          +++ rules.yml.custom    2024-05-11 15:46:18.765216285 +0100
          @@ -340,9 +340,9 @@
               - average_challenge
               #- advanced_challenge
               #- extreme_challenge
          -    - weighted_random_Levelling
          +    #- weighted_random_Levelling
               #- spawn_Levelling
          -    #- lvl-mod_spawn-blended
          +    - lvl-mod_spawn-blended
               #- ycoord_Levelling
               #- random_Levelling
               #- lvl-mod_player-variable
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
          +       nametag: disabled
          +       nametag-visibility-method: DISABLED

             - enabled: true
               name: 'Custom Nether Levelling'
        '';
      };
    })
  ];

  systemd.services.minecraft-server.preStart = mkAfter /*bash*/ ''
    mkdir -p plugins
    # Remove existing plugins
    readarray -d "" links < <(find "${dataDir}/plugins" -maxdepth 5 -type l -print0)
      for link in "''${links[@]}"; do
        if [[ "$(readlink "$link")" =~ ^${escapeShellArg builtins.storeDir} ]]; then
          rm "$link"
        fi
      done

    # Install new plugins
    ${concatStringsSep "\n" (map (plugin: /*bash*/ ''
      ln -fs "${availablePlugins.${plugin}}"/*.jar "${dataDir}/plugins"
    '') cfg.plugins)}

    # Install config files
    # We can't symlink from store becuase plugins need config write privs as
    # they merge our provided config with the default config
    ${concatStringsSep "\n" (mapAttrsToList (path: file: /*bash*/ 
      if file.value != null then ''
        rm -f "${dataDir}/${path}"
        install -m 640 -D "${pkgs.writeText "${baseNameOf path}" file.value}" "${dataDir}/${path}"
      ''
      else ''
        rm -f "${dataDir}/${path}"
        mkdir -p $(dirname "${path}")
        ${getExe pkgs.patch} -u "${file.reference}" "${pkgs.writeText "${baseNameOf path}.diff" file.diff}" -o "${dataDir}/${path}"
      ''
    ) cfg.files)}
  '';

  services.caddy.virtualHosts."squaremap.${fqDomain}".extraConfig = mkIf (pluginEnabled "squaremap") ''
    import wg-friends-only
    reverse_proxy http://127.0.0.1:25566
  '';

  networking.firewall.interfaces = (genAttrs cfg.interfaces
    (_: {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    }));

  # backups.minecraft-server = {
  #   paths = "/var/lib/minecraft";
  #   exclude = [ "cache" ".cache" ];
  #   restore.pathOwnership = { user = "minecraft"; group = "minecraft"; };
  # };

  persistence.directories = [{
    directory = "/var/lib/minecraft";
    user = "minecraft";
    group = "minecraft";
    mode = "755";
  }];
}
