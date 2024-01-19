{ outputs
, config
, pkgs
, lib
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
      blur = homeConfig.modules.desktop.hyprland.blur;
      monitor = lib.fetchers.primaryMonitor config;
      width = toString monitor.width;
      height = toString monitor.height;
      isEnd = m: boolToString (m == "end");
      refreshRate = m: toString (
        if (m == "start") then
          monitor.gamingRefreshRate
        else
          monitor.refreshRate
      );
    in
    m: pkgs.writeShellScript "gamemode-${m}" ''
      export PATH=$PATH:${scriptPrograms}
      ${optionalString hyprland /*bash*/ ''
        export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 -t /tmp/hypr | cut -d '.' -f 1 | head -1)
        hyprctl --batch "\
          ${optionalString blur "keyword decoration:blur:enabled ${isEnd m};\\"}
          keyword animations:enabled ${isEnd m};\
          keyword monitor ${monitor.name},${width}x${height}@${refreshRate m},${monitor.position},1"
      ''
      }
      notify-send --urgency=critical -t 5000 'GameMode ${m}ed'
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
