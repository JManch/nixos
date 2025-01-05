{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    getExe'
    singleton
    ;
  cfg = config.${ns}.system.desktop;
in
mkIf (cfg.enable && (cfg.displayManager.name == "greetd")) {
  assertions = lib.${ns}.asserts [
    (!config.programs.uwsm.enable)
    ''
      UWSM does not work well with greetd. Exiting the session with `loginctl
      terminate-*` causes display output to break until cycling between TTYs. I
      think it has something to do with opening the greeter user session before
      the graphical session has fully stopped.

      Instead just set "uwsm" as the display manager.
    ''
    (!cfg.displayManager.autoLogin)
    "Greetd does not support auto login (just haven't tried configuring it)"
  ];

  # WARN: Ever since https://github.com/linux-pam/linux-pam/pull/784 there
  # is a delay after entering the username during login. Because I use a
  # strong hashing algorithm it's quite noticeable.
  services.greetd = {
    enable = true;
    settings.default_session = {
      # greetd should run as the greeter user otherwise it automatically logs
      # in without prompting for password
      user = "greeter";
      command = ''
        ${getExe' pkgs.greetd.tuigreet "tuigreet"} \
        --time \
        --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions \
        --remember-session \
        --remember \
        --asterisks
      '';
    };
  };

  persistence.directories = singleton {
    directory = "/var/cache/tuigreet";
    user = "greeter";
    group = "greeter";
    mode = "0755";
  };

  persistenceHome.directories = [ ".local/share/keyrings" ];
}
