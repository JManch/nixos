{
  lib,
  cfg,
  args,
  config,
}:
let
  inherit (lib)
    ns
    mkForce
    replaceStrings
    optional
    optionalAttrs
    boolToString
    mkEnableOption
    max
    mod
    generators
    ;
  inherit (lib.${ns})
    isHyprland
    sliceSuffix
    flakePkgs
    getHyprlandMonitorConfig
    ;
  toLuaInline = generators.toLua { multiline = false; };
in
[
  {
    guardType = "first";
    enableOpt = false;
    conditions = [ (isHyprland config) ];
    opts.alwaysOnTopPatch = mkEnableOption "always on top patch";

    ns.system.desktop.uwsm.desktopNames = [ "Hyprland" ];

    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    # We configure xdg-portal with home-manager
    xdg.portal.enable = mkForce false;

    # https://discourse.nixos.org/t/how-to-enable-upstream-systemd-user-services-declaratively/7649/9
    systemd.packages = [ (flakePkgs args "hyprpolkitagent").default ];
    systemd.user.services.hyprpolkitagent = {
      path = mkForce [ ]; # reason explained in desktop/root.nix
      requisite = [ "graphical-session.target" ];
      serviceConfig.Slice = "session${sliceSuffix config}.slice";
      wantedBy = [ "graphical-session.target" ];
    };

    ns.programs.gaming.gamemode.profiles =
      let
        inherit (config.${ns}.hmNs.desktop) hyprland;
        inherit (config.${ns}.core.device) primaryMonitor;

        settings = start: ''
          hyprctl eval '
            hl.unbind(${if start then "mod" else "mod_shift_ctrl"} .. " + ${hyprland.killActiveKey}")
            hl.bind(${
              if start then "mod_shift_ctrl" else "mod"
            } .. " + ${hyprland.killActiveKey}", hl.dsp.window.close())
            hl.config({
              decoration = { blur = { enabled = ${if start then "false" else boolToString hyprland.blur} } },
              render = { direct_scanout = ${if start then boolToString hyprland.directScanout else "false"} },
            })
          ' >/dev/null
        '';

        monitor = start: ''
          hyprctl eval 'hl.monitor(${
            toLuaInline (
              getHyprlandMonitorConfig (
                primaryMonitor // optionalAttrs start { refreshRate = primaryMonitor.gamingRefreshRate; }
              )
            )
          })' >/dev/null
        '';

        # Set refresh to highest supported multiple of 60
        monitor-60 = start: ''
          hyprctl eval 'hl.monitor(${
            toLuaInline (
              getHyprlandMonitorConfig (
                primaryMonitor
                // optionalAttrs start {
                  refreshRate = max 60 (primaryMonitor.gamingRefreshRate - mod primaryMonitor.gamingRefreshRate 60);
                }
              )
            )
          })' >/dev/null
        '';
      in
      {
        "default-monitor" = {
          start."hyprland-settings" = settings true;
          stop."hyprland-settings" = settings false;
        };

        # For games locked to 60hz
        "monitor-60" = {
          start."hyprland-settings" = settings true;
          start."hyprland-monitor" = monitor-60 true;
          stop."hyprland-settings" = settings false;
          stop."hyprland-monitor" = monitor-60 false;
        };

        "default" = {
          start."hyprland-settings" = settings true;
          start."hyprland-monitor" = monitor true;
          stop."hyprland-settings" = settings false;
          stop."hyprland-monitor" = monitor false;
        };
      };
  }

  {
    nixpkgs.overlays =
      let
        hyprlandPkgs = flakePkgs args "hyprland";
      in
      [
        (final: _: {
          xdg-desktop-portal-hyprland = hyprlandPkgs.xdg-desktop-portal-hyprland.override {
            inherit (final) hyprland;
          };
          hyprland = hyprlandPkgs.hyprland.overrideAttrs (old: {
            # Remove the "+" and "=" chars from version because it gets used in the
            # package path and has to be escaped in shell scripts due to SC2276
            version = replaceStrings [ "+" "=" ] [ "-" "-" ] old.version;
            __intentionallyOverridingVersion = true;

            patches =
              (old.patches or [ ])
              ++ [
                # Fixes gestures with a mod key not consuming the mod causing
                # our fuzzel bind to get triggered on release
                ../../../../patches/hyprland-gesture-consume-mod.patch
                # Fixes our bar disappearing out when using the fullscreen
                # maximize gesture
                ../../../../patches/hyprland-fullscreen-gesture-maximize-fix.patch
                # Do not want any of the features this offers and can't be
                # bothered to get it properly working with uwsm
                ../../../../patches/hyprland-no-watchdog.patch
                # This is scuffed but should hopefully have a better solution
                # once GAMMA_LUT is implemented. Using a patch insted of wlsunset
                # or gammastep because those programs have a bunch of features I
                # don't need.
                # https://github.com/hyprwm/Hyprland/issues/9064
                ../../../../patches/hyprland-ncase-m1-monitor-gamma.patch
              ]
              # Add always on top window rule and dispatching which is pinning
              # but just for workspace that the window is on
              # TODO: Need to rebase this
              ++ optional cfg.alwaysOnTopPatch ../../../../patches/hyprland-always-on-top.patch;
          });
        })
      ];
  }
]
