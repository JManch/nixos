{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) mkIf getExe;
  cfg = config.modules.programs.gaming.gamemode;

  startStopScript =
    let
      inherit (lib) optionalString fetchers boolToString substring stringLength toUpper optional;
      inherit (homeConfig.modules.desktop) hyprland;
      homeConfig = config.home-manager.users.${username};
      isHyprland = homeConfig.modules.desktop.windowManager == "Hyprland";
      monitor = fetchers.primaryMonitor config;

      # Remap the killactive key to use the shift modifier
      killActiveRebind = isEnd: ''
        keyword unbind ${hyprland.modKey}${optionalString isEnd "SHIFTCONTROL"}, W; \
        keyword bind ${hyprland.modKey}${optionalString (!isEnd) "SHIFTCONTROL"}, W, killactive;'';

      refreshRate = m: toString (
        if (m == "start") then
          monitor.gamingRefreshRate
        else
          monitor.refreshRate
      );

      isEnd = m: boolToString (m == "end");
      blur = m: if hyprland.blur then isEnd m else "false";
      animate = m: if hyprland.animations then isEnd m else "false";
      notifBody = m: ((toUpper (substring 0 1 m)) + (substring 1 ((stringLength m) - 1) m));
    in
    mode: pkgs.writeShellApplication {
      name = "gamemode-${mode}";

      runtimeInputs = [
        pkgs.coreutils
        pkgs.libnotify
        pkgs.gnugrep
        homeConfig.wayland.windowManager.hyprland.package
      ] ++ optional isHyprland homeConfig.wayland.windowManager.hyprland.package;

      text = ''

        ${
          optionalString isHyprland /*bash*/ ''
            hyprctl --instance 0 --batch "\
              ${optionalString hyprland.blur "keyword decoration:blur:enabled ${blur mode};\\"}
              keyword animations:enabled ${animate mode}; \
              keyword monitor ${fetchers.getMonitorHyprlandCfgStr (monitor // {refreshRate = refreshRate mode;})}; \
              ${killActiveRebind (mode == "end")}"
          ''
        }

        ${if mode == "start" then cfg.startScript else cfg.stopScript}

        notify-send --urgency=critical -t 2000 \
          -h 'string:x-canonical-private-synchronous:gamemode-toggle' 'GameMode' '${notifBody mode}ed'

    '';
    };
in
mkIf cfg.enable
{
  # Do not start gamemoded for system users. This prevents gamemoded starting
  # during login when greetd temporarily runs as the greeter user.
  systemd.user.services.gamemoded = {
    unitConfig.ConditionUser = "!@system";
  };

  # Since version 1.8 gamemode requires the user to be in the gamemode group
  # https://github.com/FeralInteractive/gamemode/issues/452
  users.users.${username}.extraGroups = [ "gamemode" ];

  programs.gamemode = {
    enable = true;

    settings = {
      custom = {
        start = getExe (startStopScript "start");
        end = getExe (startStopScript "end");
      };
    };
  };
}
