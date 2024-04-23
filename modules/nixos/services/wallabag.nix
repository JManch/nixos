{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf toUpper utils;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.system) virtualisation;
  cfg = config.modules.services.wallabag;
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    virtualisation.containerisation.enable
    "Wallabag requires containerised virtualisation to be enabled"
    false
    "Wallabag module is disabled because it's insecure"
  ];

  # For various reasons this is quite an insecure module so I think I'll
  # disable it for now and wait for things to improve upstream.

  # WARN: The container creates a default admin user with username wallabag and
  # password wallabag. Change the password with this command:
  # sudo podman exec -it 8d9b5621d57e /var/www/wallabag/bin/console --env=prod fos:user:change-password

  # Unfortunately rootless podman containers on NixOS are not supported right
  # now.
  # https://github.com/NixOS/nixpkgs/issues/259770
  # https://github.com/NixOS/nixpkgs/issues/207050
  # It looks like a home-manager module will be the most likely solution.
  # https://github.com/nix-community/home-manager/pull/4331
  # https://github.com/nix-community/home-manager/pull/4801
  # (For this to work wallabag needs to be a normal user not system)

  virtualisation.oci-containers.containers.wallabag = {
    image = "wallabag/wallabag:2.6.9";
    ports = [ "0.0.0.0:${toString cfg.port}:80" ];
    environmentFiles = [ config.age.secrets.wallabagVars.path ];

    # This hopefully provides reproducibility
    imageFile = pkgs.dockerTools.pullImage {
      imageName = "wallabag/wallabag";
      imageDigest = "sha256:d482b139bab164afef0e8bbfbeb7c55cd3e10e848b95d7d167e4ffcbc847f4b9";
      sha256 = "sha256-IK2AOxk6tyCwbmkgsj7LS5zzMwwCElpN85Vt7ZzmOC8=";
      finalImageName = "wallabag/wallabag";
      finalImageTag = "2.6.9";
    };

    environment = {
      SYMFONY__ENV__DATABASE_DRIVER = "pdo_sqlite";
      SYMFONY__ENV__DATABASE_NAME = "wallabag";
      SYMFONY__ENV__DATABASE_USER = "wallabag";
      SYMFONY__ENV__DOMAIN_NAME = "http://${hostname}.lan:${toString cfg.port}";
      SYMFONY__ENV__TWOFACTOR_SENDER = "https://wallabag.${fqDomain}";
      SYMFONY__ENV__FROM_EMAIL = "wallabag@${fqDomain}";
      SYMFONY__ENV__SERVER_NAME = toUpper hostname;
    };

    volumes = [
      "/var/lib/wallabag/data:/var/www/wallabag/data"
      "/var/lib/wallabag/images:/var/www/wallabag/web/assets/images"
    ];
  };

  networking.firewall.allowedTCPPorts = [ cfg.port ];

  systemd.services.podman-wallabag.serviceConfig = {
    StateDirectory = "wallabag";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/wallabag/data 755 root root"
    "d /var/lib/wallabag/images 755 root root"
  ];

  persistence.directories = [{
    directory = "/var/lib/wallabag";
  }];
}
