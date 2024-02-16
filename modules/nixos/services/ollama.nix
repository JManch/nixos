{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf mkForce optional;
  cfg = config.modules.services.ollama;
in
mkIf cfg.enable
{
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

  networking.firewall.interfaces.wg-discord = {
    allowedTCPPorts = [ 11434 8000 ];
  };

  environment.persistence."/persist".directories = [
    # Can't actually be defined because it's a DynamicUser service.
    # /var/lib/private is persisted instead.
    # "/var/lib/private/ollama"
  ];
}
