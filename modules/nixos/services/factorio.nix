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
    # Until https://github.com/NixOS/nixpkgs/pull/338300
    package = pkgs.factorio-headless.overrideAttrs {
      version = "1.1.110";
      src = pkgs.fetchurl {
        name = "factorio_headless_x64-1.1.110.tar.xz";
        url = "https://factorio.com/get-download/1.1.110/headless/linux64";
        sha256 = "0sk4g9y051xjhiwdhj1yz808308zwsbpq3nps1ywvpp56vdycps8";
      };
    };
    public = false;
    saveName = "default";
    stateDirName = "factorio-server";
    port = cfg.port;
    bind = "0.0.0.0";
    openFirewall = true;
    nonBlockingSaving = false;
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
    mode = "755";
  };
}
