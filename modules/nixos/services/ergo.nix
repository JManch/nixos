# Bootstrap process:
# - Enable ergo.bootstrap
# - nix run n#senpai
# - hostname: localhost, port: 6667, name: admin, tls: no, password: blank
# - /oper admin <admin_password>
# - /msg NickServ SAREGISTER <MY_USERNAME> <MY_PASSWORD>
# - /quit
# Now I can auth with SASL from a remote client. If I need to setup more
# accounts I can temporarily elevate my user to admin.
{
  lib,
  cfg,
  pkgs,
  inputs,
  config,
}:
let
  inherit (lib)
    ns
    getExe
    getExe'
    genAttrs
    concatMapStringsSep
    optional
    ;
  inherit (lib.${ns}) hardeningBaseline addPatches;
  inherit (inputs.nix-resources.secrets)
    fqDomain
    ircServerName
    ircChannels
    ircAdminPassword
    ;

  ergoConf = # yaml
    ''
      network:
        name: ${ircServerName}

      server:
        name: irc.${fqDomain}

        listeners:
          # for bootstrap and file host
          "127.0.0.1:6667":
          ":6697":
            tls:
              cert: /run/credentials/ergo.service/fullchain.pem
              key: /run/credentials/ergo.service/privkey.pem
            proxy: false

        casemapping: "ascii"
        enforce-utf8: true
        lookup-hostnames: false

        idle-timeouts:
          registration: 60s
          ping: 1m30s
          disconnect: 2m30s

        relaymsg:
          enabled: true
          separators: "/"
          available-to-chanops: true

        proxy-allowed-from:
          - localhost

        max-sendq: 96k

        # compatibility with legacy clients
        compatibility:
          force-trailing: true
          send-unprefixed-sasl: true
          allow-truncation: false

        ip-limits:
          count: false
          throttle: false

        ip-cloaking:
          enabled: false

        additional-isupport:
          "soju.im/FILEHOST": "https://irc-files.${fqDomain}/upload"
          "draft/FILEHOST": "https://irc-files.${fqDomain}/upload"

      accounts:
        authentication-enabled: true

        registration:
          enabled: false

        login-throttling:
          enabled: true
          duration:  1m
          max-attempts: 3

        skip-server-password: false
        login-via-pass-command: false
        advertise-scram: true

        require-sasl:
          enabled: true
          ${
            if cfg.bootstrap then
              ''
                exempted:
                      - "localhost"
              ''
            else
              "exempted: []"
          }

        nick-reservation:
          enabled: true
          additional-nick-limit: 0
          method: strict
          allow-custom-enforcement: false
          guest-nickname-format: "Guest-*"
          force-guest-format: false
          force-nick-equals-account: true
          forbid-anonymous-nick-changes: false

        multiclient:
          enabled: true
          allowed-by-default: true
          always-on: "mandatory"
          auto-away: "mandatory"
          always-on-expiration: 0

        vhosts:
          enabled: false

      channels:
        # modes that are set when new channels are created
        # +n is no-external-messages, +t is op-only-topic,
        # +C is no CTCPs (besides ACTION)
        # see  /QUOTE HELP cmodes  for more channel modes
        default-modes: +nC
        max-channels-per-client: 100
        operator-only-creation: false

        registration:
          enabled: true
          operator-only: false
          max-channels-per-account: 50

        auto-join:
          ${concatMapStringsSep "\n    " (channel: "- \"${channel}\"") ircChannels}

      oper-classes:
        "chat-moderator":
          title: Chat Moderator

          capabilities:
            - "kill"      # disconnect user sessions
            - "ban"       # ban IPs, CIDRs, NUH masks, and suspend accounts (UBAN / DLINE / KLINE)
            - "nofakelag" # exempted from "fakelag" restrictions on rate of message sending
            - "relaymsg"  # use RELAYMSG in any channel (see the `relaymsg` config block)
            - "vhosts"    # add and remove vhosts from users
            - "sajoin"    # join arbitrary channels, including private channels
            - "samode"    # modify arbitrary channel and user modes
            - "snomasks"  # subscribe to arbitrary server notice masks
            - "roleplay"  # use the (deprecated) roleplay commands in any channel

        "server-admin":
          title: Server Admin
          extends: "chat-moderator"

          # capability names
          capabilities:
            - "rehash"       # rehash the server, i.e. reload the config at runtime
            - "accreg"       # modify arbitrary account registrations
            - "chanreg"      # modify arbitrary channel registrations
            - "history"      # modify or delete history messages
            - "defcon"       # use the DEFCON command (restrict server capabilities)
            - "massmessage"  # message all users on the server
            - "metadata"     # modify arbitrary metadata on channels and users

      opers:
        admin:
          class: "server-admin"
          hidden: true
          whois-line: is the server administrator
          password: "${ircAdminPassword}"

      logging:
        -
          method: stderr
          type: "* -userinput -useroutput"
          level: info

      debug:
        recover-from-errors: false

      datastore:
        # stores accounts
        path: ircd.db
        autoupgrade: true
        # stores history
        postgresql:
          enabled: true
          host: "localhost"
          user: "ergo"
          socket-path: "/run/postgresql"
          history-database: "ergo"
          timeout: 3s
          max-conns: 4
          application-name: "ergo"

      languages:
        # fails to load languages directories
        enabled: false
        default: en
        path: languages

      limits:
        nicklen: 32
        identlen: 20
        realnamelen: 150
        channellen: 64
        awaylen: 390
        kicklen: 390
        topiclen: 390
        monitor-entries: 100
        whowas-entries: 100
        chan-list-modes: 100
        registration-messages: 1024
        multiline:
          max-bytes: 16384
          max-lines: 10000

      fakelag:
        enabled: true
        window: 1s
        burst-limit: 5
        messages-per-window: 2
        cooldown: 2s

        command-budgets:
          "CHATHISTORY": 16
          "MARKREAD":    16
          "MONITOR":     1
          "WHO":         4
          "WEBPUSH":     1

      history:
        enabled: true
        autoresize-window: 3d
        autoreplay-on-join: 0
        chathistory-maxmessages: 1000
        znc-maxmessages: 2048
        restrictions:
          query-cutoff: 'none'

        persistent:
          enabled: true
          unregistered-channels: true
          registered-channels: "mandatory"
          direct-messages: "mandatory"

        retention:
          allow-individual-delete: true
          enable-account-indexing: false

        tagmsg-storage:
          default: true
          blacklist:
            - "+draft/typing"
            - "typing"

      allow-environment-overrides: false

      metadata:
        enabled: true
        operator-only-modification: false
        max-subs: 100
        max-keys: 100
        client-throttle:
          enabled: true
          duration: 2m
          max-attempts: 10

      webpush:
        enabled: true
        timeout: 10s
        delay: 0s
        max-subscriptions: 4
        expiration: 14d
    '';

  fileHostConf = # toml
    ''
      [http]
      listen = "tcp/localhost:${toString cfg.files.port}"

      [data]
      root = "./data"

      [auth]
      type = "sasl"

      [auth.sasl]
      server = "irc://127.0.0.1:6667"

      [limit]
      file-size = "1GB"
    '';
in
{
  requirements = [
    "services.caddy" # for the file server
    "services.postgresql"
  ];

  warnings = optional cfg.bootstrap "Ergo bootstrap is enabled; it should only be used temporarily.";

  opts = with lib; {
    bootstrap = mkOption {
      type = types.bool;
      description = ''
        Whether to allow non-SASL connection from localhost to bootstrap the admin account.
      '';
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for Ergo to be exposed on.
      '';
    };

    files = {
      port = mkOption {
        type = types.port;
        default = 8445;
        description = "File server listen port";
      };

      allowedAddresses = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          List of address to give access to IRC files.
        '';
      };
    };
  };

  services.postgresql = {
    enable = true;
    ensureUsers = [
      {
        name = "ergo";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [ "ergo" ];
  };

  systemd.services."ergo" = {
    description = "Ergo IRC Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "postgresql.target"
      "acme-irc.${fqDomain}.service"
    ];
    requires = [
      "postgresql.target"
      "acme-irc.${fqDomain}.service"
    ];
    startLimitBurst = 3;
    startLimitIntervalSec = 180;
    serviceConfig = hardeningBaseline config {
      Type = "notify";
      ExecStart = "${
        getExe (
          pkgs.ergochat.overrideAttrs {
            # The nix package has 0 features enabled
            tags = [
              "i18n"
              "postgresql"
            ];
          }
        )
      } run --conf ${pkgs.writeText "ergo.yaml" ergoConf}";
      ExecReload = "${getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = 10;
      WorkingDirectory = "/var/lib/ergo";
      StateDirectory = "ergo";
      LimitNOFILE = "1048576";
      LoadCredential = [
        "fullchain.pem:${config.security.acme.certs."irc.${fqDomain}".directory}/fullchain.pem"
        "privkey.pem:${config.security.acme.certs."irc.${fqDomain}".directory}/key.pem"
      ];
    };
  };

  systemd.services."ergo-filehost" = {
    description = "Ergo Filehost Server";
    wantedBy = [ "ergo.service" ];
    after = [ "network.target" ];
    startLimitBurst = 3;
    startLimitIntervalSec = 180;
    serviceConfig = hardeningBaseline config {
      ExecStart = "${
        # Patch fixes uploads being inaccessible for usernames containing @
        addPatches pkgs.ircv3-filehost-server [ "ircv3-filehost-server-escape-username.patch" ]
      }/bin/ircv3-filehost-server -c ${pkgs.writeText "ergo-filehost.toml" fileHostConf}";
      StateDirectory = "ergo-filehost";
      WorkingDirectory = "/var/lib/ergo-filehost";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  ns.services.caddy.virtualHosts."irc-files" = {
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.files.allowedAddresses;
    extraConfig = ''
      reverse_proxy /upload* localhost:${toString cfg.files.port}
    '';
  };

  # Have to restart instead of reload here because we're using LoadCredentials
  # https://nixos.org/manual/nixos/stable/#module-security-acme-root-owned
  security.acme.certs."irc.${fqDomain}".postRun = ''
    systemctl restart ergo.service
  '';

  networking.firewall.allowedTCPPorts = [ 6697 ];

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedTCPPorts = [
      6697
    ];
  });

  services.postgresqlBackup.databases = [ "ergo" ];

  # WARN: Not backing up the fileserver
  ns.backups."ergo" = {
    backend = "restic";
    paths = [
      "/var/lib/ergo"
      "/var/backup/postgresql/ergo.sql"
    ];
    dependencies = [ "postgresqlBackup-ergo.service" ];
    restore =
      let
        pg_restore = lib.getExe' config.services.postgresql.package "pg_restore";
        backup = "/var/backup/postgresql/ergo.sql";
      in
      {
        preRestoreScript = "sudo systemctl stop ergo";
        postRestoreScript = ''
          sudo -u postgres ${pg_restore} -U postgres --dbname postgres --clean --create ${backup}
        '';
      };
  };

  ns.persistence.directories = [
    {
      directory = "/var/lib/private/ergo";
      user = "nobody";
      group = "nogroup";
    }
    {
      directory = "/var/lib/private/ergo-filehost";
      user = "nobody";
      group = "nogroup";
    }
  ];
}
