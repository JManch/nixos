{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf mkMerge utils mapAttrs;
  inherit (config.modules.services) caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets) resticPasswordFile resticHtPasswordsFile resticRepositoryFile;
  cfg = config.modules.services.restic;
in
mkMerge [
  (mkIf (cfg.enable || cfg.server.enable) {
    environment.systemPackages = [ pkgs.restic ];
  })

  (mkIf cfg.enable {
    services.restic.backups =
      let
        backupDefaults = {
          initialize = true;
          # NOTE: Allows perform backups using the REST server, even on the same
          # machine. It simplifies permission handling.
          repositoryFile = resticRepositoryFile.path;
          passwordFile = resticPasswordFile.path;
        };
      in
      mapAttrs
        (_: value: backupDefaults // value)
        cfg.backups;
  })

  (mkIf cfg.server.enable {
    assertions = utils.asserts [
      caddy.enable
      "Restic server requires Caddy to be enabled"
    ];

    # Use `htpasswd -B -c .htpasswd username` to generate login credentials for hosts

    services.restic.server = {
      enable = true;
      dataDir = cfg.dataDir;
      # WARN: If the port is changed the restic-rest-server.socket unit has to
      # be manually restarted
      listenAddress = toString cfg.server.port;
      extraFlags = [
        "--htpasswd-file"
        "${resticHtPasswordsFile.path}"
      ];
    };

    services.caddy.virtualHosts = {
      "restic.${fqDomain}".extraConfig = ''
        import lan_only
        reverse_proxy http://127.0.0.1:${toString cfg.server.port}
      '';
    };

    programs.zsh.shellAliases.restic-repo = "sudo restic -r ${cfg.dataDir}";

    persistence.directories = [{
      directory = cfg.dataDir;
      user = "restic";
      group = "restic";
      mode = "700";
    }];
  })
]
