{
  ns,
  lib,
  inputs,
  config,
  username,
  ...
}:
let
  inherit (lib) mkIf mkMerge;
  inherit (config.${ns}.services) caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.${ns}.services.file-server;
in
mkMerge [
  (mkIf cfg.enable {
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
      # On my weak server file transfers are significantly faster over HTTP than
      # HTTPS
      forceHttp = false;
      allowTrustedAddresses = false;
      extraAllowedAddresses = cfg.allowedAddresses;
      extraConfig = ''
        root * /srv/file-server/
        file_server browse
      '';
    };
  })

  (mkIf cfg.uploadAlias.enable {
    programs.zsh.interactiveShellInit = # bash
      ''
        file-server-upload() {
          file_name=$(basename "$1")
          url_friendly_name=$(echo "$file_name" | \
            tr '[:upper:]' '[:lower:]' | \
            sed -e 's/ /-/g' -e 's/[^a-z0-9._-]//g')
          echo -e "\e[1mUploading to: http://files.${fqDomain}/$url_friendly_name\e[0m\n"
          sftp ${username}@${cfg.uploadAlias.serverAddress}:"/srv/file-server" <<< $'put '\""$1"\"' '"$url_friendly_name"
          echo -e "\n\e[1mUploaded to: http://files.${fqDomain}/$url_friendly_name\e[0m"
        }
      '';
  })
]
