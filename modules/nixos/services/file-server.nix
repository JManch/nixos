{
  lib,
  cfg,
  inputs,
  username,
}:
let
  inherit (inputs.nix-resources.secrets) fqDomain;
in
[
  {
    guardType = "first";
    requirements = [ "services.caddy" ];

    opts = with lib; {
      uploadAlias = {
        enable = mkEnableOption "shell alias for uploading files";
        serverAddress = mkOption {
          type = types.str;
          description = "File server address to use in alias";
        };
      };

      allowedAddresses = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of address to give access to the file server";
      };
    };

    users.groups.file-server = { };
    users.users.${username}.extraGroups = [ "file-server" ];
    systemd.services.caddy.serviceConfig.SupplementaryGroups = [ "file-server" ];

    systemd.tmpfiles.rules = [
      "d /srv/file-server 0770 root file-server - -"
    ];

    nsConfig.services.caddy.virtualHosts.files = {
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
  }

  (lib.mkIf cfg.uploadAlias.enable {
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
