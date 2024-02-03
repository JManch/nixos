{ config
, username
, pkgs
, lib
, ...
}:
let
  cfg = config.modules.services.greetd;
in
lib.mkIf cfg.enable
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = username;
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd ${cfg.launchCmd}";
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

  # Enable gnome keyring for saving login credentials in apps such as vscode
  # Works with greetd through pam
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd = {
    startSession = true;
    enableGnomeKeyring = true;
  };

  environment.persistence."/persist".users.${username}.directories = [
    ".local/share/keyrings"
  ];
}
