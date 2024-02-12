{ lib
, pkgs
, config
, inputs
, ...
}:
let
  cfg = config.modules.services.ollama;
in
lib.mkIf cfg.enable
{
  services.ollama = {
    enable = true;
    package = inputs.ollama.packages.${pkgs.system}.rocm;
    listenAddress = "0.0.0.0:11434";
  };
  systemd.services.ollama = {
    wantedBy = lib.mkForce (lib.lists.optional cfg.autoStart [ "multi-user.target" ]);
    environment = {
      # For ollama-ui to work
      OLLAMA_ORIGINS = "http://10.0.0.2:8000";
    };
  };
  environment.systemPackages = [ pkgs.oterm ];

  networking.firewall.interfaces.wg-discord = {
    # For ollama
    allowedTCPPorts = [ 11434 8000 ];
  };

  environment.persistence."/persist".directories = [
    # Can't actually be defined because it's a DynamicUser service.
    # /var/lib/private is persisted instead.
    # "/var/lib/private/ollama"
  ];
}
