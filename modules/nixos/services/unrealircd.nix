{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    getExe
    getExe'
    singleton
    genAttrs
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  source = pkgs.srcOnly {
    inherit (pkgs.${ns}.unrealircd) src;
    stdenv = pkgs.stdenvNoCC;
    name = "unrealircd-default-conf";
  };

  # Override state dirs for running in a systemd service
  package = pkgs.${ns}.unrealircd.override {
    logDir = "/var/log/unrealircd";
    tmpDir = "/tmp"; # safe as we enable PrivateTmp
    cacheDir = "/var/cache/unrealircd";
    # storing both data and conf in /var/lib because conf contains sensitive
    # data and /etc conf dir is vulnerable to {G,U}ID recycling with
    # DynamicUser enabled
    dataDir = "/var/lib/unrealircd/data";
    confDir = "/var/lib/unrealircd/conf";
  };
in
{
  requirements = [ "services.acme" ];

  opts = with lib; {
    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for UnrealIRCd to be exposed on.
      '';
    };
  };

  systemd.services."unrealircd" = {
    description = "UnrealIRCd IRC server";

    serviceConfig = lib.${ns}.hardeningBaseline config {
      ExecStartPre = [
        (pkgs.writeShellScript "unrealircd-setup-conf" ''
          conf_dir="$STATE_DIRECTORY/conf"

          # This is conf setup that I had to patch out of the makefile. Only run
          # when the conf dir is empty.
          if [ -d "$conf_dir" ] && [ -z "$(find "$conf_dir" -maxdepth 0 -empty)" ]; then
            exit 0
          fi

          install -Dm600 -t "$conf_dir" ${source}/doc/conf/*.default.conf
          install -Dm600 -t "$conf_dir" ${source}/doc/conf/*.optional.conf
          install -Dm600 -t "$conf_dir" ${source}/doc/conf/modules.sources.list
          install -Dm600 -t "$conf_dir" ${source}/doc/conf/spamfilter.conf
          install -Dm600 -t "$conf_dir" ${source}/doc/conf/badwords.conf
          install -Dm600 -t "$conf_dir" ${source}/doc/conf/dccallow.conf

          ${source}/extras/patches/patch_spamfilter_conf "$conf_dir" || true

          install -Dm600 -t "$conf_dir/aliases" ${source}/doc/conf/aliases/*.conf
          install -Dm600 -t "$conf_dir/help" ${source}/doc/conf/help/*.conf
          install -Dm600 -t "$conf_dir/examples" ${source}/doc/conf/examples/*.conf
          install -Dm600 -t "$conf_dir/tls" ${source}/doc/conf/tls/curl-ca-bundle.crt
          cp "$conf_dir/examples/example.conf" "$conf_dir/unrealircd.conf"
        '')
      ];

      ExecStart = "${getExe package} -F";
      # Reload the configuration. Acme will reload the service when the
      # certificates changes.
      ExecReload = "${getExe' pkgs.coreutils "kill"} -SIGHUP $MAINPID";

      # Creds will be accessible at /run/credentials/unrealircd.service/...
      LoadCredential = [
        "fullchain.pem:${config.security.acme.certs."irc.${fqDomain}".directory}/fullchain.pem"
        "privkey.pem:${config.security.acme.certs."irc.${fqDomain}".directory}/key.pem"
      ];

      # We should be storing config in the state directory cause it contains sensitive data
      # Also apply proper hardening here
      StateDirectory = "unrealircd";
      StateDirectoryMode = "700";
      CacheDirectory = "unrealircd";
      CacheDirectoryMode = "700";
      LogsDirectory = "unrealircd";
      LogsDirectoryMode = "700";
    };

    wantedBy = [ "default.target" ];
  };

  security.acme.certs."irc.${fqDomain}".reloadServices = [ "unrealircd.service" ];

  networking.firewall.allowedTCPPorts = [ 6697 ];

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedTCPPorts = [ 6697 ];
  });

  ns.persistence.directories = singleton {
    directory = "/var/lib/private/unrealircd";
    user = "nobody";
    group = "nogroup";
  };
}
