{ lib, config, ... }:
let
  cfg = config.modules.services.syncthing;
in
lib.mkIf cfg.enable {
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--home=${config.xdg.configHome}/syncthing"
      "--no-default-folder"
    ];
  };

  systemd.user.services.syncthing = {
    Unit = {
      Requires = [ "home-joshua-.config-syncthing.mount" ];
      After = [ "home-joshua-.config-syncthing.mount" ];
      X-SwitchMethod = "keep-old";
    };
  };

  # age.secrets = {
  #   syncthingCert.file = ../../../secrets/syncthing/${hostname}/cert.age;
  #   syncthingKey.file = ../../../secrets/syncthing/${hostname}/key.age;
  # };
  #
  # This doesn't work cause home-manager doesn't want to touch files outside of home
  # Could probably resolve with some kind of oneshot systemd service that
  # copies the files to correct locations
  # Although there's no point implementing this until syncthing config is fully
  # declarative so I'll just wait on this
  # xdg.configFile."syncthing/cert.pem".source = /. + config.age.secrets.syncthingCert.path;
  # xdg.configFile."syncthing/key.pem".source = /. + config.age.secrets.syncthingKey.path;

  persistence.directories = [ ".config/syncthing" ];
}
