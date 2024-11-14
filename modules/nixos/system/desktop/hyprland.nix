{
  ns,
  lib,
  config,
  ...
}@args:
let
  inherit (lib)
    mkIf
    mkForce
    getExe
    ;
  inherit (lib.${ns}) asserts isHyprland flakePkgs;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.desktop;
  hyprlandPackage = config.hm.wayland.windowManager.hyprland.package;
in
mkIf (cfg.enable && isHyprland config) {
  assertions = asserts [
    homeManager.enable
    "Hyprland requires Home Manager to be enabled"
  ];

  programs.hyprland.enable = true;

  # We configure xdg-portal with home-manager
  xdg.portal.enable = mkForce false;

  programs.uwsm = {
    enable = true;
    waylandCompositors.hyprland = {
      binPath = getExe hyprlandPackage;
      prettyName = "Hyprland";
      comment = "Hyprland managed by UWSM";
    };
  };

  # https://discourse.nixos.org/t/how-to-enable-upstream-systemd-user-services-declaratively/7649/9
  systemd.packages = [ (flakePkgs args "hyprpolkitagent").default ];
  systemd.user.services.hyprpolkitagent.wantedBy = [ "graphical-session.target" ];

  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };
}
