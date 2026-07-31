{
  lib,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib) ns mkIf generators;
  inherit (lib.${ns}) isHyprland getHyprlandMonitorConfig;
  inherit (osConfig.${ns}.core.device) primaryMonitor;
  toLuaInline = generators.toLua { multiline = false; };
in
{
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

  categoryConfig = {
    gameClasses = [ "osu!" ];
    gamemode.profiles.osu = mkIf (isHyprland config) {
      start."tablet" = ''
        hyprctl eval '
          hl.monitor(${
            toLuaInline (
              getHyprlandMonitorConfig (primaryMonitor // { refreshRate = primaryMonitor.gamingRefreshRate; })
            )
          })
          hl.config({
            input = {
              tablet = {
                region_position = "0 0",
                region_size = "0 0",
                active_area_size = "96 54",
                active_area_position = "28 20.5",
                output = "${primaryMonitor.name}",
              },
            },
          })
        ' >/dev/null
      '';

      # FIX: Hyprland bug: active_area_size cannot be reset by setting it to 0 0
      stop."tablet" = ''
        hyprctl eval '
          hl.monitor(${toLuaInline (getHyprlandMonitorConfig primaryMonitor)})
          hl.config({
            input = {
              tablet = {
                active_area_size = "152 95",
                active_area_position = "0 0",
                output = "current",
              },
            },
          })
        ' >/dev/null
      '';
    };
  };

  ns.persistence.directories = [ ".local/share/osu" ];
}
