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
    mkIf
    singleton
    mkForce
    optional
    ;
  inherit (config.${ns}.core) device;
  inherit (inputs.nix-resources.secrets) fqDomain;
in
[
  {
    enableOpt = false;
    opts = with lib; {
      worker = {
        enable = mkEnableOption "llama-cpp worker";
        autoStart = mkEnableOption "auto start";

        port = mkOption {
          type = types.port;
          default = 1337;
          description = "Port for the llama-server to listen on";
        };

        model = mkOption {
          type = types.str;
          default = null;
          description = "Absolute path to model";
        };

        extraSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
        };
      };

      proxy = {
        enable = mkEnableOption "llama-server proxy";

        address = mkOption {
          type = types.str;
          default = null;
          description = "Address of the proxied llama-server";
        };

        port = mkOption {
          type = types.port;
          default = 1337;
          description = "Port of the proxied llama-server";
        };

        certFile = mkOption {
          type = types.str;
          description = ''
            Cert file of the host we are proxying to. MUST be signed with the same address we proxy to.
          '';
        };
      };
    };
  }

  (mkIf cfg.worker.enable {
    asserts = [
      (hostname == "ncase-m1")
      "llama-cpp is only configured to work on host 'ncase-m1'"
    ];

    services."llama-cpp" = {
      enable = true;
      package = pkgs.llama-cpp-vulkan;
      openFirewall = true;
      settings = {
        host = "0.0.0.0";
        port = cfg.worker.port;
        model = cfg.worker.model;
        fit = "on";
        fit-target = 1024; # default is 1024
        fit-ctx = 4096; # default is 4096
        cache-type-k = "q8_0";
        cache-type-v = "q8_0";
        cache-ram = device.memory / 2;
        cors-origins = "https://llm.${fqDomain}";
        sleep-idle-seconds = 60 * 120;
        temp = "0.8";
        top-p = "0.95";
        top-k = 40;
        min-p = "0.05";
      }
      // cfg.worker.extraSettings;
    };

    systemd.services."llama-cpp".wantedBy = mkForce (optional cfg.worker.autoStart "multi-user.target");

    ns.persistence.directories = singleton {
      directory = "/var/lib/private/llama-cpp";
      user = "nobody";
      group = "nogroup";
      mode = "0700";
    };
  })

  (mkIf cfg.proxy.enable {
    ns.services.caddy.virtualHosts."llm".extraConfig = ''
      reverse_proxy ${cfg.proxy.address}:${toString cfg.proxy.port} {
        transport http {
          tls_trust_pool file ${cfg.proxy.certFile}
          tls_server_name ${cfg.proxy.address}
        }

        flush_interval -1
      }
    '';
  })
]
