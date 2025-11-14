{
  lib,
  args,
  config,
  hostname,
}:
let
  inherit (lib)
    ns
    mkForce
    replaceStrings
    optional
    ;
  inherit (lib.${ns}) isHyprland sliceSuffix flakePkgs;
in
[
  {
    guardType = "first";
    enableOpt = false;
    conditions = [ (isHyprland config) ];

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
                # Makes the togglespecialworkspace dispatcher always toggle instead
                # of moving the open special workspace to the active monitor
                ../../../../patches/hyprland-special-workspace-toggle.patch
                ../../../../patches/hyprland-resize-params-floats.patch
                # Fixes center and size/move window rules using the active monitor instead
                # of the monitor that the window is on
                ../../../../patches/hyprland-windowrule-monitor.patch
                # Makes exact resizeparams in dispatchers relative to the window's current
                # monitor instead of the last active monitor
                ../../../../patches/hyprland-better-resize-args.patch
                # Add always on top window rule and dispatching which is pinning
                # but just for workspace that the window is on
                ../../../../patches/hyprland-always-on-top.patch
                # Always override the monitor in repeated windowrules. Allows us
                # to change workspace monitors layouts in our external monitor
                # layout scripts with `hyprctl keyword workspace x, monitor:`
                ../../../../patches/hyprland-workspacerules-monitor.patch
                # Add fullscreenMode to `hyprctl workspaces`
                ../../../../patches/hyprland-hyprctl-workspace-fullscreen-mode.patch
                # Adds dynamic mode to the resize gesture which moves the window
                # if it's floating
                ../../../../patches/hyprland-dynamic-resize-gesture.patch
                ../../../../patches/hyprland-fullscreen-gesture-maximize-fix.patch
              ]
              # This is scuffed but should hopefully have a better solution
              # once GAMMA_LUT is implemented. Using a patch insted of wlsunset
              # or gammastep because those programs have a bunch of features I
              # don't need.
              # https://github.com/hyprwm/Hyprland/issues/9064
              ++ optional (hostname == "ncase-m1") ../../../../patches/hyprland-ncase-m1-monitor-gamma.patch;
          });
        })
      ];

    nix.settings = {
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
  }
]
