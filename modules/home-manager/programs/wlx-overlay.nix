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

  systemd.user.services.wlx-overlay-s-openxr = {
    Unit = {
      Description = "WLX Overlay S OpenXR";
      After = [ "monado.service" ];
      BindsTo = [ "monado.service" ];
      Requires = [
        "monado.socket"
        "graphical-session.target"
      ];
    };

    Service = {
      Slice = "app${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = "${getExe pkgs.wlx-overlay-s} --show";
    };

    Install.WantedBy = [ "monado.service" ];
  };

  systemd.user.services.wlx-overlay-s-openvr = {
    Unit = {
      Description = "WLX Overlay S OpenVR";
      Requires = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "app${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = "${getExe pkgs.wlx-overlay-s} --openvr --show";
    };
  };

  persistence.directories = [ ".config/wlxoverlay" ];
}
