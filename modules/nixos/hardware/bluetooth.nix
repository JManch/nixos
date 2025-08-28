{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    hiPrio
    mkForce
    ;
  inherit (config.${ns}.core) home-manager device;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = device.type != "laptop";
  };

  services.blueman.enable = true;

  systemd.user.services.blueman-applet = {
    path = mkForce [ ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
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

    (hiPrio (
      pkgs.runCommand "blueman-adapter-desktop-entry-disable" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.blueman}/share/applications/blueman-adapters.desktop $out/share/applications/blueman-adapters.desktop \
          --replace-fail "Type=Application" "Type=Application
        Hidden=true"
      ''
    ))
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.settings.windowrule = [
      "float, class:^(.blueman-manager-wrapped)$"
      "size 40% 40%, class:^(.blueman-manager-wrapped)$"
      "center, class:^(.blueman-manager-wrapped)$"
    ];
  };

  ns.persistence.directories = [
    "/var/lib/bluetooth"
    "/var/lib/blueman"
  ];
}
