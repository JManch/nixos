{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) ns getExe;
in
{
  enableOpt = false;
  conditions = [ "osConfigStrict.hardware.valveIndex" ];

  home.packages = [ pkgs.wlx-overlay-s ];

  systemd.user.services.wlx-overlay-s-openxr = {
    Unit = {
      Description = "OpenXR Overlay";
      After = [
        "graphical-session.target"
        "monado.service"
      ];

      PartOf = [
        "monado.service"
        "graphical-session.target"
      ];

      Requisite = [
        "graphical-session.target"
        "monado.service"
        "monado.socket"
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
      Description = "OpenVR Overlay";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "app${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = "${getExe pkgs.wlx-overlay-s} --openvr --show";
    };
  };

  nsConfig.persistence.directories = [ ".config/wlxoverlay" ];
}
