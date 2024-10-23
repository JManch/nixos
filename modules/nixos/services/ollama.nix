{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    singleton
    optional
    genAttrs
    ;
  cfg = config.${ns}.services.ollama;
in
mkIf cfg.enable {
  userPackages = [ pkgs.oterm ];

  services.ollama = {
    enable = true;
    user = "ollama";
    group = "ollama";
    listenAddress = "0.0.0.0:11434";
  };

  systemd.services.ollama = {
    wantedBy = mkForce (optional cfg.autoStart [ "multi-user.target" ]);
    environment = {
      # For ollama-ui to work
      OLLAMA_ORIGINS = "http://10.0.0.2:8000";
    };
  };

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedTCPPorts = [
      11434
      8000
    ];
  });

  persistence.directories = singleton {
    directory = "/var/lib/private/ollama";
    user = "ollama";
    group = "ollama";
    mode = "0755";
  };
}
