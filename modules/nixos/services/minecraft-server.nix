{ lib
, pkgs
, config
, inputs
, outputs
, ...
}:
let
  inherit (lib) mkIf mkMerge escapeShellArg concatStringsSep mkAfter genAttrs elem mapAttrsToList mapAttrs;
  inherit (config.services.minecraft-server) dataDir;
  inherit (config.age.secrets) minecraftSecrets;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.minecraft-server;

  files = mapAttrs (name: value: pkgs.writeText "${baseNameOf name}" value) cfg.files;
  availablePlugins = outputs.packages.${pkgs.system}.minecraft-plugins;
  pluginEnabled = p: elem p cfg.plugins;
in
mkIf cfg.enable
{
  environment.systemPackages = [ pkgs.mcrcon ];

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
      # We just use rcon locally as a convenient way to access the console
      enable-rcon = true;
      "rcon.port" = 25575;
      "rcon.password" = "secret";
    };
  };

  modules.services.minecraft-server.files = mkMerge [
    (mkIf (pluginEnabled "aura-skills") {
      "plugins/AuraSkills/config.yml" = /*yaml*/ ''
        on_death:
          reset_xp: true
      '';
    })

    (mkIf (pluginEnabled "vivecraft") {
      "plugins/Vivecraft-Spigot-Extensions/config.yml" = /*yaml*/ ''
        general:
          bow:
            standingmultiplier: 1
            seatedheadshotmultiplier: 2
          welcomemsg:
            enabled: true
            welcomeVanilla: '&player has joined with non-VR!'
          crawling:
            enabled: true
          teleport:
            enabled: false
      '';
    })

    (mkIf (pluginEnabled "squaremap") {
      "plugins/squaremap/config.yml" = /*yaml*/ ''
        settings:
          web-address: https://squaremap.${fqDomain}
          internal-webserver:
            bind: 127.0.0.1
            port: 25566
      '';
    })
  ];

  systemd.services.minecraft-server = {
    serviceConfig.EnvironmentFile = minecraftSecrets.path;

    preStart = mkAfter /*bash*/ ''
      mkdir -p plugins
      # Remove existing plugins and files
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

      # TODO: Need a way to modify existing files because plugins do not like
      # having their config files replaced

      # Install files
      ${concatStringsSep "\n" (mapAttrsToList (file: text: /*bash*/ ''
        rm -f "${dataDir}/${file}"
        # Plugins have a tendancy to write to config files for some reason
        install -m 640 -D "${text}" "${dataDir}/${file}"
      '') files)}
    '';
  };

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
