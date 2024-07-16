{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    optional
    genAttrs
    ;
  cfg = config.modules.services.ollama;
in
mkIf cfg.enable {
  environment.systemPackages = [ pkgs.oterm ];

  services.ollama = {
    enable = true;
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

  persistence.directories = [
    # NOTE: Can't be persisted because Ollama is a DynamicUser service so the
    # bind mount cannot match permissions. More info in impermanence.nix.
    # /var/lib/private is persisted instead.

    # "/var/lib/private/ollama"
  ];
}
