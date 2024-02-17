{ lib
, pkgs
, config
, ...
} @ args:
let
  cfg = config.modules.programs.gaming.gamemode;
  homeConfig = lib.utils.homeConfig args;
  isHyprland = homeConfig.modules.desktop.windowManager == "Hyprland";

  scriptPrograms = lib.makeBinPath ([
    pkgs.coreutils
    pkgs.libnotify
    homeConfig.wayland.windowManager.hyprland.package
  ] ++ lib.lists.optional isHyprland homeConfig.wayland.windowManager.hyprland.package);

  # Because the script will be called from steam's FHS environment we have to
  # explicity set environment variables
  script =
    let
      inherit (lib) optionalString;
      inherit (builtins) toString;

      hyprCfg = homeConfig.modules.desktop.hyprland;
      monitor = lib.fetchers.primaryMonitor config;
      isEnd = m: lib.trivial.boolToString (m == "end");

      # In gamemode remap the killactive key to use the shift modifier
      killactiveUnbind = isEnd:
        "keyword unbind ${hyprCfg.modKey}${optionalString isEnd "SHIFTCONTROL"}, W";

      killactiveBind = isEnd:
        "keyword bind ${hyprCfg.modKey}${optionalString (!isEnd) "SHIFTCONTROL"}, W, killactive";

      refreshRate = m: toString (
        if (m == "start") then
          monitor.gamingRefreshRate
        else
          monitor.refreshRate
      );

      blur = m: if hyprCfg.blur then isEnd m else false;
      animate = m: if hyprCfg.animations then isEnd m else false;

      notifBody = with builtins; m: ((lib.strings.toUpper (substring 0 1 m)) + (substring 1 ((stringLength m) - 1) m));
    in
    m: pkgs.writeShellScript "gamemode-${m}" ''
      export PATH=$PATH:${scriptPrograms}
      ${optionalString isHyprland /*bash*/ ''
        export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 -t /tmp/hypr | cut -d '.' -f 1 | head -1)
        hyprctl --batch "\
          ${optionalString hyprCfg.blur "keyword decoration:blur:enabled ${blur m};\\"}
          keyword animations:enabled ${animate m};\
          keyword monitor ${lib.fetchers.getMonitorHyprlandCfgStr (monitor // {refreshRate = refreshRate m;})};\
          ${killactiveUnbind (m == "end")};\
          ${killactiveBind (m == "end")};"
      ''
      }
      notify-send --urgency=critical -t 2000 -h 'string:x-canonical-private-synchronous:gamemode-toggle' 'GameMode' '${notifBody m}ed'
    '';
in
lib.mkIf cfg.enable {
  programs.gamemode = {
    enable = true;
    settings = {
      custom = {
        start = (script "start").outPath;
        end = (script "end").outPath;
      };
    };
  };
}
