{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf mkBefore mkVMOverride getExe' utils;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  cfg = config.modules.services.calibre;
in
mkIf (hostname == "homelab" && cfg.enable && caddy.enable)
{
  services.calibre-web = {
    enable = true;
    listen.ip = "127.0.0.1";
    listen.port = cfg.port;
    options = {
      enableBookUploading = true;
      calibreLibrary = "/var/lib/calibre-library";
    };
  };

  systemd.services.calibre-web.serviceConfig = utils.hardeningBaseline config {
    DynamicUser = false;
    ReadWritePaths = [ "/var/lib/calibre-library" ];
  };

  services.caddy.virtualHosts."calibre.${fqDomain}".extraConfig = ''
    import lan_only
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  # Expose wireless server for kobo ereader transfers
  networking.firewall.allowedTCPPorts = [ 9090 ];

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
