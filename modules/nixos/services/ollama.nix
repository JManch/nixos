{
  lib,
  cfg,
  pkgs,
  config,
  hostname,
}:
let
  inherit (lib)
    mkIf
    singleton
    genAttrs
    mkForce
    optional
    ;
in
[
  {
    opts = with lib; {
      autoStart = mkEnableOption "autostart";

      openWebUI = {
        enable = mkEnableOption "OpenWebUI";
        openFirewall = mkEnableOption "exposing open-webui on primary interfaces";

        port = mkOption {
          type = types.port;
          default = 11111;
          description = "OpenWebUI listening port";
        };

        interfaces = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            List of additional interfaces for open-webui to be exposed on.
          '';
        };
      };
    };

    asserts = [
      (hostname == "ncase-m1")
      "Ollama is only configured to work on host 'ncase-m1'"
    ];

    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      # Since my 7900xt isn't "offically" supported by rocm I need this
      # Only needed with the rocm package
      # rocmOverrideGfx = "11.0.0";
      host = "0.0.0.0";
      port = 11434;
      # https://www.canirun.ai/
      syncModels = true; # will delete models not listed bellow
      loadModels = [ "qwen3.5:9b" ];
    };

    systemd.services = {
      ollama.wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
      ollama-model-loader.wantedBy = mkForce [ "ollama.service" ];
    };

    ns.persistence.directories = singleton {
      directory = "/var/lib/private/ollama";
      user = "nobody";
      group = "nogroup";
      mode = "0755";
    };
  }

  (mkIf cfg.openWebUI.enable {
    services.open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = cfg.openWebUI.port;
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
        OLLAMA_API_BASE_URL = "http://127.0.0.1:${config.services.ollama.port}";
        WEBUI_AUTH = "False";
      };
    };

    systemd.services = {
      open-webui.wantedBy = mkForce [ "ollama.service" ];
      open-webui.partOf = [ "ollama.service" ];
    };

    networking.firewall = {
      allowedTCPPorts = optional cfg.openFirewall cfg.openWebUI.port;
      interfaces = genAttrs cfg.interfaces (_: {
        allowedTCPPorts = [ cfg.openWebUI.port ];
      });
    };

    ns.persistence.directories = singleton {
      directory = "/var/lib/private/open-webui";
      user = "nobody";
      group = "nogroup";
      mode = "0755";
    };
  })
]
