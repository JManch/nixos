{
  lib,
  config,
  hostname,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    genAttrs
    mkForce
    optional
    ;
  cfg = config.${ns}.services.ollama;
in
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    (hostname == "ncase-m1")
    "Ollama is only intended to work on host 'ncase-m1'"
  ];

  services.ollama = {
    enable = true;
    user = "ollama";
    group = "ollama";
    host = "0.0.0.0";
    port = 11434;
    acceleration = "rocm";
    # Since my 7900xt isn't "offically" supported by rocm I need this
    rocmOverrideGfx = "11.0.0";
    loadModels = [
      "llama3.2"
      "qwen2.5-coder:32b-instruct-q3_K_M"
      "qwen2.5:32b-instruct-q3_K_M"
      "mistral-small:22b-instruct-2409-q5_1"
    ];
  };

  systemd.services = {
    ollama.wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
    ollama-model-loader.wantedBy = mkForce [ "ollama.service" ];
    open-webui.wantedBy = mkForce [ "ollama.service" ];
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

  users.groups.open-webui = { };
  users.users.open-webui = {
    group = "open-webui";
    isSystemUser = true;
  };

  systemd.services.open-webui.serviceConfig = {
    User = "open-webui";
    Group = "open-webui";
  };

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedTCPPorts = [
      11434
      11111
    ];
  });

  persistence.directories = [
    {
      directory = "/var/lib/private/ollama";
      user = "ollama";
      group = "ollama";
      mode = "0755";
    }
    {
      directory = "/var/lib/private/open-webui";
      user = "open-webui";
      group = "open-webui";
      mode = "0755";
    }
  ];
}
