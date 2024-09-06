{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  hostname,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mapAttrs
    getExe
    mkVMOverride
    toUpper
    concatStringsSep
    concatMapStrings
    concatMapStringsSep
    genAttrs
    singleton
    ;
  inherit (lib.${ns}) asserts hardeningBaseline;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.${ns}.system.virtualisation) vmVariant;
  cfg = config.${ns}.services.caddy;

  generateCerts =
    let
      # We define these here rather than in the modules where they are used so that
      # certificates can be generated on devices other than the server
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
mkMerge [
  { adminPackages = [ generateCerts ]; }
  (mkIf cfg.enable {
    assertions = asserts [
      (cfg.trustedAddresses != [ ])
      "Caddy requires trusted addresses to be set"
    ];

    services.caddy = {
      enable = true;
      # Does not work when the admin API is off
      enableReload = false;

      globalConfig = ''
        admin off
      '';

      virtualHosts."logs.${fqDomain}".extraConfig = ''
        ${cfg.allowAddresses cfg.trustedAddresses}
        root * /var/lib/goaccess/
        file_server * browse

        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }
        reverse_proxy @websockets http://127.0.0.1:7890
      '';
    };

    networking.firewall.allowedTCPPorts = [
      443
      80
    ];
    networking.firewall.allowedUDPPorts = [ 443 ];
    ${ns}.system.networking.publicPorts = [
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
        unitConfig = {
          Description = "GoAccess log analyzer";
          PartOf = [ "caddy.service" ];
          After = [
            "caddy.service"
            "network.target"
          ];
          StartLimitBurst = 3;
          StartLimitIntervalSec = 30;
        };

        serviceConfig = {
          ExecStart = runGoAccess.outPath;
          Restart = "on-failure";
          RestartSec = 10;
          User = "caddy";
          Group = "caddy";
          StateDirectory = [ "goaccess" ];
        } // hardeningBaseline config { DynamicUser = false; };

        wantedBy = [ "multi-user.target" ];
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

    persistence.directories =
      let
        inherit (config.services) caddy;
      in
      singleton {
        directory = "/var/lib/caddy";
        user = caddy.user;
        group = caddy.group;
        mode = "700";
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
  })
]
