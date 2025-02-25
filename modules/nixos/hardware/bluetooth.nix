{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    hiPrio
    ;
  inherit (config.${ns}.core) homeManager;
in
{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  systemd.user.services.blueman-applet = {
    path = mkForce [ ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig.Slice = "session${lib.${ns}.sliceSuffix config}.slice";
  };

  environment.systemPackages = [
    (hiPrio (
      pkgs.runCommand "blueman-autostart-disable" { } ''
        mkdir -p $out/etc/xdg/autostart
        substitute ${pkgs.blueman}/etc/xdg/autostart/blueman.desktop $out/etc/xdg/autostart/blueman.desktop \
          --replace-fail "Type=Application" "Type=Application
        Hidden=true"
      ''
    ))
  ];

  hm = mkIf homeManager.enable {
    desktop.hyprland.settings.windowrulev2 = [
      "float, class:^(.blueman-manager-wrapped)$"
      "size 30% 30%, class:^(.blueman-manager-wrapped)$"
      "center, class:^(.blueman-manager-wrapped)$"
    ];
  };

  persistence.directories = [
    "/var/lib/bluetooth"
    "/var/lib/blueman"
  ];
}
