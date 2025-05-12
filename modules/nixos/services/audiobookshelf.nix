{
  lib,
  cfg,
  config,
}:
let
  inherit (lib) ns singleton;
  inherit (lib.${ns}) hardeningBaseline;
in
{
  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Port for the audiobookshelf to listen on";
    };

    extraAllowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of extra address to give access to audiobookshelf in addition to
        the Caddy trusted addreses.
      '';
    };
  };

  services.audiobookshelf = {
    enable = true;
    openFirewall = false;
    host = "127.0.0.1";
    port = cfg.port;
  };

  systemd.services.audiobookshelf.serviceConfig = hardeningBaseline config {
    DynamicUser = false;
    MemoryDenyWriteExecute = false;
    SystemCallFilter = [
      "@system-service"
      "~@resources"
    ];
  };

  ns.backups.audiobookshelf = {
    paths = [ "/var/lib/audiobookshelf/metadata/backups" ];
    restore.pathOwnership."/var/lib/audiobookshelf" = {
      user = "audiobookshelf";
      group = "audiobookshelf";
    };
  };

  ns.services.caddy.virtualHosts.audiobooks = {
    inherit (cfg) extraAllowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  ns.persistence.directories = singleton {
    directory = "/var/lib/audiobookshelf";
    user = "audiobookshelf";
    group = "audiobookshelf";
    mode = "0700";
  };
}
