{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf mkBefore mkVMOverride getExe' utils;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  cfg = config.modules.services.calibre;
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    caddy.enable
    "Calibre requires Caddy to be enabled"
  ];

  services.calibre-web = {
    enable = true;
    # Patch increases file size upload limit from 200MB to 2GB
    # https://github.com/janeczku/calibre-web/issues/452
    # Also fixes unwanted gamma adjusted of cover images
    # https://github.com/janeczku/calibre-web/issues/2564
    package = utils.addPatches pkgs.calibre-web [ ../../../patches/calibre-web.patch ];
    listen.ip = "127.0.0.1";
    listen.port = cfg.port;
    options = {
      enableBookUploading = true;
      calibreLibrary = "/var/lib/calibre-library";
    };
  };

  systemd.services.calibre-web.serviceConfig = utils.hardeningBaseline config {
    DynamicUser = false;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    ReadWritePaths = [ "/var/lib/calibre-library" ];
  };

  services.caddy.virtualHosts."calibre.${fqDomain}".extraConfig = ''
    import lan-only
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  # Expose wireless server for kobo ereader transfers
  networking.firewall.allowedTCPPorts = [ 9090 ];

  backups.calibre = {
    paths = [
      "/var/lib/calibre-web"
      "/var/lib/calibre-library"
    ];

    restore.pathOwnership =
      let
        ownership = { user = "calibre-web"; group = "calibre-web"; };
      in
      {
        "/var/lib/calibre-web" = ownership;
        "/var/lib/calibre-library" = ownership;
      };
  };

  persistence.directories = [
    {
      directory = "/var/lib/calibre-web";
      user = "calibre-web";
      group = "calibre-web";
      mode = "700";
    }
    {
      directory = "/var/lib/calibre-library";
      user = "calibre-web";
      group = "calibre-web";
      mode = "700";
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
      services.calibre-web = {
        listen.ip = mkVMOverride "0.0.0.0";
      };

      systemd.services.calibre-web.serviceConfig = {
        ExecStartPre = mkBefore [ createDummyLibrary.outPath ];
      };

      networking.firewall.allowedTCPPorts = [ cfg.port ];
    };
}
