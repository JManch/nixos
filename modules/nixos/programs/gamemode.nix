{ lib
, pkgs
, config
, ...
} @ args:
let
  homeConfig = lib.utils.homeConfig args;
  gaming = config.modules.programs.gaming;

  scriptPrograms = lib.makeBinPath [
    homeConfig.wayland.windowManager.hyprland.package
    pkgs.coreutils
    pkgs.libnotify
  ];

  # Because the script will be called from steam's FHS environment we have to
  # explicity set environment variables
  script =
    let
      inherit (lib) optionalString;
      inherit (lib.trivial) boolToString;
      inherit (builtins) toString;
      hyprland = homeConfig.modules.desktop.windowManager == "hyprland";
      hyprlandConfig = homeConfig.modules.desktop.hyprland;
      blur = hyprlandConfig.blur;
      monitor = lib.fetchers.primaryMonitor config;
      width = toString monitor.width;
      height = toString monitor.height;
      isEnd = m: boolToString (m == "end");
      # In gamemode remap the killactive key to use the shift modifier
      killactiveUnbind = isEnd:
        "keyword unbind ${hyprlandConfig.modKey}${optionalString isEnd "SHIFTCONTROL"}, W";
      killactiveBind = isEnd:
        "keyword bind ${hyprlandConfig.modKey}${optionalString (!isEnd) "SHIFTCONTROL"}, W, killactive";
      refreshRate = m: toString (
        if (m == "start") then
          monitor.gamingRefreshRate
        else
          monitor.refreshRate
      );
      notifBody = with builtins; m: ((lib.strings.toUpper (substring 0 1 m)) + (substring 1 ((stringLength m) - 1) m));
    in
    m: pkgs.writeShellScript "gamemode-${m}" ''
      export PATH=$PATH:${scriptPrograms}
      ${optionalString hyprland /*bash*/ ''
        export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 -t /tmp/hypr | cut -d '.' -f 1 | head -1)
        hyprctl --batch "\
          ${optionalString blur "keyword decoration:blur:enabled ${isEnd m};\\"}
          keyword animations:enabled ${isEnd m};\
          keyword monitor ${monitor.name},${width}x${height}@${refreshRate m},${monitor.position},1;\
          ${killactiveUnbind (m == "end")};\
          ${killactiveBind (m == "end")};"
      ''
      }
      notify-send --urgency=critical -t 2000 -h 'string:x-canonical-private-synchronous:gamemode-toggle' 'GameMode' '${notifBody m}ed'
    '';
in
lib.mkIf gaming.enable {
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
