{
  lib,
  cfg,
  hostname,
}:
let
  inherit (lib) genAttrs mkForce optional;
in
{
  opts = with lib; {
    autoStart = mkEnableOption "autostart";
    openFirewall = mkEnableOption "exposing open-webui on primary interfaces";

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for open-webui to be exposed on.
      '';
    };
  };

  asserts = [
    (hostname == "ncase-m1")
    "Ollama is only configured to work on host 'ncase-m1'"
  ];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "rocm";
    # Since my 7900xt isn't "offically" supported by rocm I need this
    rocmOverrideGfx = "11.0.0";
    loadModels = [ "deepseek-r1:14b-qwen-distill-q4_K_M" ];
  };

  systemd.services = {
    ollama.wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
    ollama-model-loader.wantedBy = mkForce [ "ollama.service" ];
    open-webui.wantedBy = mkForce [ "ollama.service" ];
    open-webui.partOf = [ "ollama.service" ];
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 11111;
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
    };
  };

  networking.firewall = {
    allowedTCPPorts = optional cfg.openFirewall 11111;
    interfaces = genAttrs cfg.interfaces (_: {
      allowedTCPPorts = [ 11111 ];
    });
  };

  ns.persistence.directories = [
    {
      directory = "/var/lib/private/ollama";
      user = "nobody";
      group = "nogroup";
      mode = "0755";
    }
    {
      directory = "/var/lib/private/open-webui";
      user = "nobody";
      group = "nogroup";
      mode = "0755";
    }
  ];
}
