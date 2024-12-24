{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (lib) ns mkIf getExe;
in
mkIf (osConfig.${ns}.hardware.valve-index.enable or false) {
  home.packages = [ pkgs.wlx-overlay-s ];

  systemd.user.services.wlx-overlay-s = {
    Unit = {
      Description = "Lightweight OpenXR/OpenVR overlay for Wayland and X11 desktops";
      After = [ "monado.service" ];
      BindsTo = [ "monado.service" ];
      Requires = [
        "monado.socket"
        "graphical-session.target"
      ];
    };
    Service.ExecStart = "${getExe pkgs.wlx-overlay-s} --show";
    Install.WantedBy = [ "monado.service" ];
  };

  persistence.directories = [ ".config/wlxoverlay" ];
}
