{
  ns,
  lib,
  config,
  username,
  ...
}:
let
  inherit (config.${ns}.services) caddy;
  cfg = config.${ns}.services.file-server;
in
lib.mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    caddy.enable
    "File server requires Caddy to be enabled"
  ];

  users.users.${username}.extraGroups = [ "file-server" ];
  users.groups.file-server = { };

  systemd.tmpfiles.rules = [
    "d /srv/file-server 0775 root file-server - -"
  ];

  ${ns}.services.caddy.virtualHosts.files = {
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.allowedAddresses;
    extraConfig = ''
      root * /srv/file-server/
      file_server browse
    '';
  };
}
