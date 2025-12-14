{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkBefore getExe;
  tomat = lib.${ns}.addPatches pkgs.tomat [
    # Show session number during breaks
    "tomat-always-show-sessions.patch"
    "tomat-disable-notification-icon.patch"
    # Exit with exit code 1 if the watch command fails to connect to the
    # daemon. Fixes waybar not hiding the module when the daemon is stopped.
    "tomat-watch-exit-code.patch"
    # I would rather use my own icons and this allows me to set waybar
    # icon based on the state using format-icons.
    "tomat-alt-field.patch"
  ];
in
{
  home.packages = [
    (pkgs.symlinkJoin {
      name = "tomat-start-service";
      paths = [ tomat ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/tomat \
          --run '
        if ! systemctl is-active --quiet --user tomat.service; then
          systemctl start --user tomat.service && sleep 0.5
        fi
        '
      '';
    })
  ];

  xdg.configFile."tomat/config.toml".source = (pkgs.formats.toml { }).generate "config.toml" {
    timer = {
      work = 50;
      break = 10;
      long_break = 20;
      sessions = 3;
      auto_advance = true;
    };

    sound = {
      enable = true;
      volume = 0.4;
    };

    notification = {
      enable = true;
      timeout = 10000;
    };

    display.text_format = "{phase} {session} {time}";
  };

  systemd.user.services."tomat" = {
    Unit = {
      Description = "Tomat pomodoro timer daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${getExe tomat} daemon run";
      ExecStop = "${getExe tomat} daemon stop";
    };
  };

  programs.waybar.settings.bar = {
    modules-right = mkBefore [ "custom/tomat" ];
    "custom/tomat" = {
      # WARN: Do not replace the substitutions here as the tomat in PATH
      # auto-starts the service and sleeps
      exec = "${getExe tomat} watch --interval 1 2>/dev/null";
      restart-interval = 30; # attempt to reconnect to the daemon every 30 secs
      return-type = "json";
      format = "<span color='#${config.colorScheme.palette.base04}'>{icon}</span> {text}";
      format-icons = {
        work = "󱎫";
        work-paused = "";
        break = "󰅶";
        break-paused = "";
        long-break = "";
        long-break-paused = "";
      };
      tooltip = false;
      on-click = "${getExe tomat} toggle";
      on-click-middle = "${getExe tomat} skip";
      on-click-right = "systemctl stop --user tomat.service && ${getExe pkgs.libnotify} --urgency=critical -t 5000 'Tomat' 'Service stopped'";
    };
  };
}
