{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib)
    ns
    getExe
    getExe'
    ;
  inherit (lib.${ns}) sliceSuffix mkHyprExec;
  inherit (osConfig.${ns}.core.device) primaryMonitor;
in
{
  home.packages = [ pkgs.wayvnc ];

  systemd.user.services.wayvnc = {
    Unit = {
      Description = "Wayland VNC Server";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      ExecStart = "${getExe pkgs.wayvnc} --output=${primaryMonitor.name} --gpu --log-level info";
    };
  };

  systemd.user.services.novnc = {
    Unit = {
      Description = "noVNC Client Web Server";
      After = [ "wayvnc.service" ];
      BindsTo = [ "wayvnc.service" ];
    };

    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      ExecStart = "${getExe pkgs.novnc} --listen 127.0.0.1:6080 --vnc 127.0.0.1:5900";
      SuccessExitStatus = 143;
    };

    Install.WantedBy = [ "wayvnc.service" ];
  };

  programs.zsh.initContent = # bash
    ''
      vnc-start() {
        systemctl start --user wayvnc
        echo "Start SSH tunnel with \`ssh -L 6080:127.0.0.1:6080 username@hostname\`"
        echo "Alternatively forward port 5900 for direct VNC connection"
        echo "Open http://localhost:6080/vnc.html to connect"
      }

      vnc-stop() {
        systemctl stop --user wayvnc
      }
    '';

  # Since VNC clients usually have a button for this key combination and we
  # don't use it for anything else
  ns.desktop.hyprland.binds = [
    (mkHyprExec "" "ALT + CONTROL + Delete" "${getExe' pkgs.wayvnc "wayvncctl"} output-cycle")
  ];
}
