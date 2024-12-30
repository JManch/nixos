{ lib, config, ... }@args:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mkForce
    replaceStrings
    ;
  inherit (lib.${ns}) asserts isHyprland flakePkgs;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.desktop;
in
mkMerge [
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

            patches = (old.patches or [ ]) ++ [
              # Makes the togglespecialworkspace dispatcher always toggle instead
              # of moving the open special workspace to the active monitor
              ../../../../patches/hyprlandSpecialWorkspaceToggle.patch
              ../../../../patches/hyprlandResizeParamsFloats.patch
              # Potential fix for https://github.com/hyprwm/Hyprland/issues/6820
              ../../../../patches/hyprlandSpecialWorkspaceFullscreen.patch
              # Fixes center and size/move window rules using the active monitor instead
              # of the monitor that the window is on
              ../../../../patches/hyprlandWindowRuleMonitor.patch
              # Makes exact resizeparams in dispatchers relative to the window's current
              # monitor instead of the last active monitor
              ../../../../patches/hyprlandBetterResizeArgs.patch
            ];
          });
        })
      ];

    nix.settings = {
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
  }

  (mkIf (cfg.enable && isHyprland config) {
    assertions = asserts [
      homeManager.enable
      "Hyprland requires Home Manager to be enabled"
    ];

    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    # We configure xdg-portal with home-manager
    xdg.portal.enable = mkForce false;

    # https://discourse.nixos.org/t/how-to-enable-upstream-systemd-user-services-declaratively/7649/9
    systemd.packages = [ (flakePkgs args "hyprpolkitagent").default ];
    systemd.user.services.hyprpolkitagent.wantedBy = [ "graphical-session.target" ];
  })
]
