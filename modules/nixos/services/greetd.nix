{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf getExe' utils;
  cfg = config.modules.services.greetd;
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    config.usrEnv.desktop.enable
    "Greetd requires desktop to be enabled"
    (cfg.sessionDirs != [ ])
    "Greetd session dirs must be set"
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # greetd should run as the greeter user, this settings is not related
        # to the user that will log in
        user = "greeter";
        command = ''
          ${getExe' pkgs.greetd.tuigreet "tuigreet"} \
          --time \
          --sessions ${cfg.sessionDirs} \
          --remember \
          --remember-session
        '';
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

  persistence.directories = [{
    directory = "/var/cache/tuigreet";
    user = "greeter";
    group = "greeter";
    mode = "755";
  }];

  persistenceHome.directories = [ ".local/share/keyrings" ];
}
