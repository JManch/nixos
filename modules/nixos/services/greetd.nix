{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) mkIf getExe';
  cfg = config.modules.services.greetd;
in
mkIf (cfg.enable && config.usrEnv.desktop.enable)
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = username;
        command = "${getExe' pkgs.greetd.tuigreet "tuigreet"} -t -s ${cfg.sessionDirs}";
      };
    };
  };

  # These settings ensure that boot logs won't get spammed over greetd
  # https://github.com/apognu/tuigreet/issues/68#issuecomment-1586359960
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # Enable gnome keyring for saving login credentials in apps such as VSCode
  # Works with greetd through pam
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd = {
    startSession = true;
    enableGnomeKeyring = true;
  };

  persistenceHome.directories = [ ".local/share/keyrings" ];
}
