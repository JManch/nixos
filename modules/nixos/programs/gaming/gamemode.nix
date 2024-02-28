{ lib, pkgs, config, ... } @ args:
let
  inherit (lib) mkIf utils getExe;
  cfg = config.modules.programs.gaming.gamemode;

  startStopScript =
    let
      inherit (lib) optionalString fetchers boolToString substring stringLength toUpper optional;
      inherit (homeConfig.modules.desktop) hyprland;
      homeConfig = utils.homeConfig args;
      isHyprland = homeConfig.modules.desktop.windowManager == "Hyprland";
      monitor = fetchers.primaryMonitor config;

      # Remap the killactive key to use the shift modifier
      killActiveRebind = isEnd: ''
        "keyword unbind ${hyprland.modKey}${optionalString isEnd "SHIFTCONTROL"}, W"; \
        "keyword bind ${hyprland.modKey}${optionalString (!isEnd) "SHIFTCONTROL"}, W, killactive";
      '';

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

      runtimeInputs = with pkgs; [
        coreutils
        libnotify
        homeConfig.wayland.windowManager.hyprland.package
      ] ++ optional isHyprland homeConfig.wayland.windowManager.hyprland.package;

      text = ''

        ${
          optionalString isHyprland /*bash*/ ''
            # shellcheck disable=SC2012
            HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 -t /tmp/hypr | cut -d '.' -f 1 | head -1)
            export HYPRLAND_INSTANCE_SIGNATURE
            hyprctl --batch "\
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
mkIf cfg.enable {
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
