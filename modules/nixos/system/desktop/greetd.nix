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
mkIf (cfg.enable && (cfg.displayManager == "greetd")) {
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

  persistence.directories = singleton {
    directory = "/var/cache/tuigreet";
    user = "greeter";
    group = "greeter";
    mode = "0755";
  };

  persistenceHome.directories = [ ".local/share/keyrings" ];
}
