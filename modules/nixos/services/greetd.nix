{ config
, username
, pkgs
, lib
, ...
}:
let
  cfg = config.modules.services.greetd;
in
lib.mkIf (cfg.enable) {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd ${cfg.launchCmd}";
        user = "${username}";
      };
    };
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
