{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) ns mkIf getExe';
  inherit (lib.${ns}) isHyprland getMonitorHyprlandCfgStr;
  inherit (osConfig.${ns}.device) primaryMonitor;
  cfg = config.${ns}.programs.gaming.osu;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
in
mkIf cfg.enable {
  home.packages = [
    # The upstream flatpak uses an illegal XDG desktop file ID which breaks
    # UWSM app launcher (we patch the Exec command at the same time)
    # https://specifications.freedesktop.org/desktop-entry-spec/latest/file-naming.html
    (pkgs.osu-lazer-bin.overrideAttrs (old: {
      buildCommand =
        old.buildCommand
        # bash
        + ''
          substitute $out/share/applications/osu\!.desktop $out/share/applications/osu.desktop \
            --replace-fail "Exec=osu! %u" "Exec=env GAMEMODE_PROFILES=osu gamemoderun osu! %u"
          rm $out/share/applications/osu\!.desktop
        '';
    }))
  ];

  ${ns}.programs.gaming = {
    gameClasses = [ "osu!" ];
    gamemode.profiles.osu = mkIf (isHyprland config) {
      start = ''
        ${hyprctl} --instance 0 --batch "\
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
      stop = ''
        ${hyprctl} --instance 0 --batch "\
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
