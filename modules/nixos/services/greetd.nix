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
}
