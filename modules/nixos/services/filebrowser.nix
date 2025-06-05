{
  lib,
  cfg,
  config,
}:
let
  inherit (lib) ns singleton optional;
  inherit (config.${ns}.system) impermanence;
in
{
  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 8093;
      description = "Port for the filebrowser server to listen on";
    };

    allowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of address to give access to the filebrowser server";
    };
  };

  requirements = [
    "services.caddy"
    "!services.file-server"
  ];

  fileSystems."/var/lib/filebrowser/data" = {
    fsType = "tmpfs";
    depends = optional impermanence.enable "/persist/var/lib/filebrowser";
    options = [
      "defaults"
      "size=3g"
      "mode=755"
    ];
  };

  services.filebrowser = {
    enable = true;
    openFirewall = false;
    settings = {
      root = "/var/lib/filebrowser/data";
      port = cfg.port;
    };
  };

  systemd.services.filebrowser.serviceConfig.StateDirectoryMode = "0700";

  ns.services.caddy.virtualHosts.files = {
    forceHttp = false;
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.allowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  ns.persistence.directories = singleton {
    directory = "/var/lib/filebrowser";
    user = "filebrowser";
    group = "filebrowser";
    mode = "0700";
  };
}
