{
  lib,
  cfg,
  config,
}:
let
  inherit (lib) ns singleton;
in
{
  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the sliverbullet to listen on";
    };
  };

  requirements = [ "services.caddy" ];

  services.silverbullet = {
    enable = true;
    openFirewall = false;
    listenPort = cfg.port;
    listenAddress = "127.0.0.1";
  };

  systemd.services.silverbullet.serviceConfig = lib.${ns}.hardeningBaseline config {
    DynamicUser = false;
    StateDirectoryMode = "0700";
    SystemCallFilter = [
      "~@privileged"
      "~@resources"
    ];
    MemoryDenyWriteExecute = false;
  };

  ns.services.caddy.virtualHosts.notes.extraConfig = ''
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  ns.persistence.directories = singleton {
    directory = "/var/lib/silverbullet";
    user = "silverbullet";
    group = "silverbullet";
    mode = "0700";
  };
}
