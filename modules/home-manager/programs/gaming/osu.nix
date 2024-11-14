{
  ns,
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib) mkIf hiPrio;
  inherit (lib.${ns}) isHyprland getMonitorHyprlandCfgStr;
  inherit (osConfig'.${ns}.device) primaryMonitor;
  cfg = config.${ns}.programs.gaming.osu;
in
mkIf cfg.enable {
  home.packages = [
    pkgs.osu-lazer-bin
    (hiPrio (
      pkgs.runCommand "osu-desktop-gamemoderun" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.osu-lazer-bin}/share/applications/osu\!.desktop $out/share/applications/osu\!.desktop \
          --replace-fail "Exec=osu! %u" "Exec=env GAMEMODE_PROFILES=osu gamemoderun osu! %u"
      ''
    ))
  ];

  ${ns}.programs.gaming = {
    gameClasses = [ "osu!" ];
    gamemode.profiles.osu = mkIf (isHyprland config) {
      startScript = ''
        hyprctl --instance 0 --batch "\
          keyword monitor ${
            getMonitorHyprlandCfgStr (primaryMonitor // { refreshRate = primaryMonitor.gamingRefreshRate; })
          }; \
          keyword input:tablet:region_position 0 0; \
          keyword input:tablet:region_size 0 0; \
          keyword input:tablet:active_area_size 96 54; \
          keyword input:tablet:active_area_position 28 20.5; \
          keyword input:tablet:output '${primaryMonitor.name}'; \
        "
      '';

      # FIX: Hyprland bug: active_area_size cannot be reset by setting it to 0 0
      stopScript = ''
        hyprctl --instance 0 --batch "\
          keyword monitor ${getMonitorHyprlandCfgStr primaryMonitor}; \
          keyword input:tablet:active_area_size 152 95; \
          keyword input:tablet:active_area_position 0 0; \
          keyword input:tablet:output current; \
        "
      '';
    };
  };

  persistence.directories = [
    ".local/share/osu"
  ];
}
