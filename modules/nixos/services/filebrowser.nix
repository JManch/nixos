{
  lib,
  cfg,
}:
{
  opts = with lib; {
    storeInRam = mkEnableOption "storing files on a tmpfs";

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

  services.filebrowser = {
    enable = true;
    openFirewall = false;
    settings = {
      root = "/var/lib/filebrowser/data";
      port = cfg.port;
    };
  };

  systemd.services.filebrowser.serviceConfig = {
    TemporaryFileSystem = lib.mkIf cfg.storeInRam "/var/lib/filebrowser/data:size=20%";
    StateDirectoryMode = "0700";
    SuccessExitStatus = [
      0
      1
    ];
  };

  ns.services.caddy.virtualHosts.files = {
    forceHttp = false;
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.allowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/filebrowser";
    user = "filebrowser";
    group = "filebrowser";
    mode = "0700";
  };
}
