{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf mkForce;
  inherit (lib.${ns}) asserts isHyprland;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.desktop;
  hyprlandPackage = config.hm.wayland.windowManager.hyprland.package;
in
mkIf (cfg.enable && isHyprland config) {
  assertions = asserts [
    homeManager.enable
    "Hyprland requires Home Manager to be enabled"
  ];

  # The purpose of enabling hyprland here (in addition to enabling it in
  # home-manager) is to create the hyprland.desktop session file which
  # enables login GUI managers to launch hyprland. However we use greetd
  # which is unique in the sense that it doesn't use session files. Instead
  # it uses a manually-configured launch command. Other login managers
  # would let the user pick a desktop session from a list of options
  # (generated from the .desktop session files).

  # Ultimately this means that enabling hyprland on the system-level is
  # unnecessary if we're using greetd. Regardless, we enable it for
  # compatibility with other login managers.
  programs.hyprland = {
    enable = true;
    package = hyprlandPackage;
    # Extra variables are required in the dbus and systemd environment for
    # xdg-open to work using portals (the preferred method). This option
    # adds them to the systemd user environment.
    # https://github.com/NixOS/nixpkgs/issues/160923
    # https://github.com/hyprwm/Hyprland/issues/2800
    systemd.setPath.enable = true;
  };

  # We configure xdg-portal with home-manager
  xdg.portal.enable = mkForce false;

  ${ns}.services.greetd.sessionDirs = [ "${hyprlandPackage}/share/wayland-sessions" ];

  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };
}
