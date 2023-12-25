{
  pkgs,
  config,
  ...
}: let
  pgrep = "${pkgs.procps}/bin/pgrep";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  lockCommand = "${config.xdg.configHome}/hypr/scripts/lock_screen.sh";
  lockTime = 3 * 60;
  screenOffTime = 5 * 60;
in {
  home.packages = with pkgs; [
    procps
  ];

  services.swayidle = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    timeouts = [
      {
        timeout = lockTime;
        command = "${lockCommand}";
      }
      {
        timeout = screenOffTime;
        command = "${pgrep} swaylock && ${hyprctl} dispatch dpms off";
        resumeCommand = "${hyprctl} dispatch dpms on";
      }
    ];
    # events = [
    #   {
    #     event = "before-sleep";
    #     command = "${lockCommand}";
    #   }
    # ];
  };
}
