{ lib, cfg }:
let
  inherit (lib) genAttrs singleton;
in
{
  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 34197;
      description = "Port for the Factorio server to listen on";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for the Factorio server to be exposed
        on
      '';
    };
  };

  services.factorio = {
    enable = true;
    requireUserVerification = false;
    public = false;
    saveName = "default";
    stateDirName = "factorio-server";
    port = cfg.port;
    bind = "0.0.0.0";
    openFirewall = true;
    nonBlockingSaving = true;
    loadLatestSave = true;
    lan = true;
    game-name = "NixOS Factorio Server";
  };

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedUDPPorts = [ cfg.port ];
  });

  users.users.factorio = {
    group = "factorio";
    isSystemUser = true;
  };
  users.groups.factorio = { };

  systemd.services.factorio.serviceConfig = {
    User = "factorio";
    Group = "factorio";
  };

  ns.backups.factorio-server = {
    backend = "restic";
    paths = [ "/var/lib/private/factorio-server" ];
    restore.pathOwnership = {
      "/var/lib/private/factorio-server" = {
        user = "factorio";
        group = "factorio";
      };
    };
  };

  ns.persistence.directories = singleton {
    directory = "/var/lib/private/factorio-server";
    user = "factorio";
    group = "factorio";
    mode = "0755";
  };
}
