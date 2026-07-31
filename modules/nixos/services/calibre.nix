{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkBefore
    mkVMOverride
    getExe'
    ;
  inherit (lib.${ns}) addPatches hardeningBaseline;
in
{
  requirements = [ "services.caddy" ];

  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 8083;
    };

    extraAllowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of address to give access to Jellyfin in addition to the trusted
        list.
      '';
    };
  };

  services.calibre-web = {
    enable = true;
    # Patch increases file size upload limit from 200MB to 2GB
    # https://github.com/janeczku/calibre-web/issues/452
    # Also fixes unwanted gamma adjusted of cover images
    # https://github.com/janeczku/calibre-web/issues/2564
    package = addPatches pkgs.calibre-web [ "calibre-web.patch" ];
    listen.ip = "127.0.0.1";
    listen.port = cfg.port;
    options = {
      enableBookUploading = true;
      calibreLibrary = "/var/lib/calibre-library";
    };
  };

  systemd.services.calibre-web.serviceConfig = hardeningBaseline config {
    StateDirectory = "calibre-web";
    DynamicUser = false;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
    ];
    ReadWritePaths = [ "/var/lib/calibre-library" ];
  };

  ns.services.caddy.virtualHosts.calibre = {
    inherit (cfg) extraAllowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  # Expose wireless server for kobo ereader transfers
  networking.firewall.allowedTCPPorts = [ 9090 ];

  ns.backups.calibre = {
    backend = "restic";

    paths = [
      "/var/lib/calibre-web"
      "/var/lib/calibre-library"
    ];

    restore.pathOwnership =
      let
        ownership = {
          user = "calibre-web";
          group = "calibre-web";
        };
      in
      {
        "/var/lib/calibre-web" = ownership;
        "/var/lib/calibre-library" = ownership;
      };
  };

  ns.persistence.directories = [
    {
      directory = "/var/lib/calibre-web";
      user = "calibre-web";
      group = "calibre-web";
      mode = "0755";
    }
    {
      directory = "/var/lib/calibre-library";
      user = "calibre-web";
      group = "calibre-web";
      mode = "0700";
    }
  ];

  virtualisation.vmVariant =
    let
      createDummyLibrary = pkgs.writeShellScript "create-dummy-calibre-library" ''
        if [[ -f "/var/lib/calibre-library/metadata.db" ]]; then
          exit 0;
        fi
        lib="/var/lib/calibre-library"
        touch "$lib/book.txt"
        ${getExe' pkgs.calibre "calibredb"} add "$lib/book.txt" --with-library "$lib"
      '';
    in
    {
      services.calibre-web.listen.ip = mkVMOverride "0.0.0.0";

      systemd.services.calibre-web.serviceConfig = {
        ExecStartPre = mkBefore [ createDummyLibrary.outPath ];
      };

      networking.firewall.allowedTCPPorts = [ cfg.port ];
    };
}
