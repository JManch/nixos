{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  hostname,
}:
let
  inherit (lib)
    ns
    all
    mapAttrs
    mapAttrs'
    getExe
    attrNames
    mkVMOverride
    toUpper
    concatStringsSep
    optionalString
    concatMapStrings
    nameValuePair
    concatMapStringsSep
    genAttrs
    singleton
    mkOption
    types
    optionals
    mkEnableOption
    ;
  inherit (lib.${ns}) hardeningBaseline;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets) caddyPorkbunVars;
  inherit (config.${ns}.system.virtualisation) vmVariant;

  generateCerts =
    let
      certDomains = [ "home-wan" ];

      genDomain =
        domain: # bash
        ''
          openssl genrsa -out "$temp/${domain}.key" 4096
          openssl req -new -sha256 -key "$temp/${domain}.key" -out "$temp/${domain}.csr" \
            -subj "/C=GB/O=${toUpper hostname}/CN=${domain}.${fqDomain}"
          openssl x509 -req -in "$temp/${domain}.csr" -CA "$temp/rootCA.crt" -CAkey "$temp/rootCA.key" -CAcreateserial -out "$temp/${domain}.crt" -days 365 -sha256
          cat "$temp/${domain}.crt" "$temp/${domain}.key" > "$temp/${domain}.pem"
          openssl pkcs12 -export -out "$dir/${domain}.p12" -inkey "$temp/${domain}.key" -in "$temp/${domain}.pem" 
          mv "$temp/${domain}.crt" "$dir"
        '';
    in
    pkgs.writeShellApplication {
      name = "generate-caddy-certs";
      runtimeInputs = [ pkgs.openssl ];
      text = # bash
        ''
          umask 077
          dir="generated-certs"
          if [ ! -d "$dir" ]; then
              mkdir "$dir"
          else
              echo "Output directory '$dir' already exists"
              exit 1
          fi

          temp=$(mktemp -d)
          cleanup() {
            rm -rf "$temp"
          }
          trap cleanup EXIT

          # Generate new root certificate authority
          openssl genrsa -out "$temp/rootCA.key" 4096
          openssl req -x509 -new -nodes -key "$temp/rootCA.key" -sha256 -days 365 -out "$temp/rootCA.crt" \
            -subj "/C=GB/O=${toUpper hostname}/CN=Joshua's Root Certificate"

          # Generate leaf certificate for each domain
          ${concatMapStrings (d: genDomain d) certDomains}

          mv "$temp/rootCA.crt" "$dir"
          echo "Update the encrypted certificates in agenix with the new *.crt files in $dir"
          echo "Import the *.p12 files into browsers and devices you want to grant access to"
          echo "Unfortunately custom certs do not work on firefox mobile https://bugzilla.mozilla.org/show_bug.cgi?id=1813930, have to use chrome for that now"
          echo "Remember to backup the *.p12 files somewhere safe"
        '';
    };
in
{
  opts = {
    interfaces = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of additional interfaces for Caddy to be exposed on.
      '';
    };

    trustedAddresses = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        "192.168.89.2/32"
        "192.168.88.0/24"
      ];
      description = ''
        List of address ranges representing the trusted local network. Use in
        combination with allowAddresses to restrict access to virtual hosts.
      '';
    };

    extraFail2banTrustedAddresses = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        Caddy fail2ban filter addresses to trust in addition to trusted
        addresses. Does not affect virtual host access.
      '';
    };

    goAccessExcludeIPRanges = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of address ranges excluded from go access using their strange
        format.
      '';
    };

    virtualHosts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              forceHttp = mkEnableOption ''
                forcing the virtual host to use HTTP instead of HTTPS
              '';

              allowTrustedAddresses =
                mkEnableOption ''
                  access to this virtual host from all trusted address as
                  configured with `caddy.trustedAddresses`
                ''
                // {
                  default = true;
                };

              extraAllowedAddresses = mkOption {
                type = with types; listOf str;
                default = [ ];
                description = ''
                  Extra addresses in addition to the trusted address (assuming
                  `allowTrustedAddresses` is enabled) to give access to this
                  virtual host.
                '';
              };

              allowedAddresses = mkOption {
                type = with types; listOf str;
                readOnly = true;
                default =
                  (optionals config.allowTrustedAddresses cfg.trustedAddresses) ++ config.extraAllowedAddresses;
              };

              extraConfig = mkOption {
                type = types.lines;
                default = null;
                description = ''
                  Extra config to append to the virtual host, like the upstream
                  option
                '';
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Wrapper for Caddy virtual host config that configures DNS ACME and
        remote IP address blocking.
      '';
    };
  };

  asserts = [
    (cfg.trustedAddresses != [ ])
    "Caddy requires trusted addresses to be set"
    (all (subdomain: cfg.virtualHosts.${subdomain}.allowedAddresses != [ ]) (
      attrNames cfg.virtualHosts
    ))
    ''
      Caddy virtual host has no allowed addresses. This is probably bad as it
      may allow access from all addresses.
    ''
  ];

  ns.adminPackages = [ generateCerts ];

  services.caddy = {
    enable = true;
    enableReload = false;

    package =
      # FIX: Using Caddy 2.9.1 until https://github.com/caddy-dns/porkbun/issues/24 is resolved
      # After updating to 2.10 we can use the new global DNS option to avoid
      # needing DNS config in every virtual host
      (import (fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/5e5402ecbcb27af32284d4a62553c019a3a49ea6.tar.gz";
        sha256 = "sha256:0a8xv91nz7qkyxs3nhszxj3vb9s5v1xgyhmm32y1fbb8njx7hrw1";
      }) { inherit (pkgs) system; }).caddy.withPlugins
        {
          plugins = [ "github.com/caddy-dns/porkbun@v0.2.1" ];
          hash = "sha256-X8QbRc2ahW1B5niV8i3sbfpe1OPYoaQ4LwbfeaWvfjg=";
        };

    globalConfig = ''
      admin off
    '';

    virtualHosts = mapAttrs' (
      subdomain: cfg':
      nameValuePair "${optionalString cfg'.forceHttp "http://"}${subdomain}.${fqDomain}" {
        # Instead of using the global acme_dns option we have to configure
        # ACME DNS on every host. This is because it's not possible to use a
        # custom resolver in the global option. We need a custom resolver
        # because our local DNS server redirects requests to our domain which
        # breaks the DNS challenge somehow.
        # I think this describes the issue I was facing:
        # https://github.com/go-acme/lego/issues/1754#issuecomment-1441038533
        extraConfig = ''
          tls {
            dns porkbun {
              api_key {env.PORKBUN_API_KEY}
              api_secret_key {env.PORKBUN_SECRET_API_KEY}
            }
            resolvers 1.1.1.1
          }

          @block {
            not remote_ip ${concatStringsSep " " cfg'.allowedAddresses}
          }
          respond @block "Access denied" 403 {
            close
          }

          ${cfg'.extraConfig}
        '';
      }
    ) config.${ns}.services.caddy.virtualHosts;
  };

  ns.services.caddy.virtualHosts.logs.extraConfig = ''
    root * /var/lib/goaccess/
    file_server * browse

    @websockets {
      header Connection *Upgrade*
      header Upgrade websocket
    }
    reverse_proxy @websockets http://127.0.0.1:7890
  '';

  networking.firewall.allowedUDPPorts = [ 443 ];
  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedTCPPorts = [
      443
      80
    ];
    allowedUDPPorts = [ 443 ];
  });

  # Extra hardening
  systemd.services.caddy.serviceConfig = hardeningBaseline config {
    EnvironmentFile = caddyPorkbunVars.path;
    DynamicUser = false;
    PrivateUsers = false;
    SystemCallFilter = [
      "@system-service"
      "~@resources"
    ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    SocketBindDeny = "any";
    SocketBindAllow = [
      443
      80
    ];
  };

  systemd.services.goaccess =
    let
      runGoAccess = pkgs.writeShellScript "run-caddy-goaccess" ''
        # Get list of all caddy access logs
        logs=""
        # shellcheck disable=SC2044
        for file in $(${getExe pkgs.findutils} "/var/log/caddy" -type f -name "*.${fqDomain}.log"); do
          logs+=" $file"
        done

        exec ${getExe pkgs.goaccess} $logs \
          --log-format=CADDY \
          --real-time-html \
          --ws-url=logs.${fqDomain}:${if vmVariant then "50080" else "443"} \
          --port=7890 \
          --real-os \
          ${concatMapStringsSep " " (ip: "--exclude-ip ${ip}") cfg.goAccessExcludeIPRanges} \
          -o /var/lib/goaccess/index.html
      '';
    in
    {
      description = "GoAccess";
      partOf = [ "caddy.service" ];
      after = [
        "caddy.service"
        "network.target"
      ];
      wantedBy = [ "caddy.service" ];
      startLimitBurst = 3;
      startLimitIntervalSec = 30;

      serviceConfig = hardeningBaseline config {
        DynamicUser = false;
        ExecStart = runGoAccess.outPath;
        Restart = "on-failure";
        RestartSec = 10;
        User = "caddy";
        Group = "caddy";
        StateDirectory = [ "goaccess" ];
        StateDirectoryMode = "0750";
      };
    };

  services.fail2ban.jails.caddy-status = {
    enabled = true;

    settings = {
      ignoreip = concatStringsSep " " (cfg.trustedAddresses ++ cfg.extraFail2banTrustedAddresses);
      logpath = "/var/log/caddy/access-*.log";
      port = "http,https";
      backend = "auto";
    };

    filter.Definition = {
      failregex = ''^.*"remote_ip":"<HOST>",.*?"status":(?:401|403|404|500),.*$'';
      ignoreregex = "";
      datepattern = ''"ts":{Epoch}\.'';
    };
  };

  ns.persistence.directories =
    let
      inherit (config.services) caddy;
    in
    singleton {
      directory = "/var/lib/caddy";
      user = caddy.user;
      group = caddy.group;
      mode = "0755";
    };

  virtualisation.vmVariant = {
    ${ns}.services.caddy.trustedAddresses = [ "10.0.2.2/32" ];

    services.caddy = {
      # Confusingly auto_https off doesn't actually server all hosts of http
      # Each virtualhost needs to explicity specify http://
      # https://caddy.community/t/making-sense-of-auto-https-and-why-disabling-it-still-serves-https-instead-of-http/9761
      globalConfig = ''
        debug
        auto_https off
      '';

      # Prefix every hostname with http://
      virtualHosts = mkVMOverride (
        mapAttrs (
          _: value: value // { hostName = ("http://" + value.hostName); }
        ) config.services.caddy.virtualHosts
      );
    };
  };
}
