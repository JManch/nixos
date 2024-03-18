{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf mkBefore mkVMOverride getExe';
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.calibre;
in
mkIf cfg.enable
{
  services.calibre-web = {
    enable = true;
    listen.ip = "127.0.0.1";
    listen.port = 8083;
    options = {
      enableBookUploading = true;
      calibreLibrary = "/var/lib/calibre-library";
    };
  };

  services.caddy.virtualHosts."calibre.${fqDomain}".extraConfig = ''
    import lan_only
    reverse_proxy http://127.0.0.1:8083
    # Might need this
    # {
    #   header_up X-Script-Name /calibre-web
    # }
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

      networking.firewall.allowedTCPPorts = [ 8083 ];
    };
}
