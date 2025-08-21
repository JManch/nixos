{
  lib,
  cfg,
  config,
}:
{
  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the sliverbullet to listen on";
    };

    allowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of address to give access to silverbullet";
    };
  };

  requirements = [ "services.caddy" ];

  # nixos module is out of date and broken
  # WARN: Remember to change ownership of secrets, persist directories and
  # backup restores when switching to nixos module

  # services.silverbullet = {
  #   enable = true;
  #   package = pkgs.silverbullet.overrideAttrs (old: {
  #     version = "0-unstable";
  #     src = fetchurl {
  #       url = "";
  #       hash = "";
  #     };
  #   });
  #   openFirewall = false;
  #   listenPort = cfg.port;
  #   listenAddress = "127.0.0.1";
  # };

  virtualisation.oci-containers.containers."silverbullet" = {
    image = "ghcr.io/silverbulletmd/silverbullet:v2";
    pull = "always";
    ports = [ "127.0.0.1:${toString cfg.port}:3000" ];
    volumes = [ "/var/lib/silverbullet:/space" ];
    environmentFiles = [ config.age.secrets.silverbulletVars.path ];
    # Can't get rootless podman to work unfortunately
    # podman.users = "silverbullet";
  };

  systemd.services."podman-silverbullet".serviceConfig = {
    StateDirectory = "silverbullet";
    StateDirectoryMode = "0700";
  };

  ns.services.caddy.virtualHosts."notes" = {
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.allowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  ns.backups."silverbullet" = {
    backend = "restic";
    paths = [ "/var/lib/silverbullet" ];
  };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/silverbullet";
    mode = "0700";
  };
}
