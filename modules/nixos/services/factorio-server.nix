{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf genAttrs singleton;
  cfg = config.${ns}.services.factorio-server;
in
mkIf cfg.enable {
  services.factorio = {
    enable = true;
    package = pkgs.factorio-headless.overrideAttrs rec {
      version = "2.0.20";
      src = pkgs.fetchurl {
        name = "factorio_headless_x64-${version}.tar.xz";
        url = "https://factorio.com/get-download/${version}/headless/linux64";
        hash = "sha256-xKkB8vHb7btBZUVg20xvq2g6MMIDNOgF1O90DAQWUVo=";
      };
    };
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

  backups.factorio-server = {
    paths = [ "/var/lib/private/factorio-server" ];
    restore.pathOwnership = {
      "/var/lib/private/factorio-server" = {
        user = "factorio";
        group = "factorio";
      };
    };
  };

  persistence.directories = singleton {
    directory = "/var/lib/private/factorio-server";
    user = "factorio";
    group = "factorio";
    mode = "0755";
  };
}
