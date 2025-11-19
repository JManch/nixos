{
  lib,
  pkgs,
  args,
  config,
}:
let
  inherit (lib) ns mkIf hiPrio;
  inherit (config.${ns}.core) home-manager device;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = device.type != "laptop";
  };

  ns.userPackages = [
    (lib.${ns}.wrapHyprlandMoveToActive args pkgs.bluetui "bluetui" "")
    (hiPrio (
      pkgs.runCommand "bluetui-desktop-modify" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.bluetui}/share/applications/bluetui.desktop $out/share/applications/bluetui.desktop \
          --replace-fail "Exec=bluetui" "Exec=xdg-terminal-exec --title=bluetui --app-id=bluetui bluetui
        Icon=preferences-bluetooth" \
          --replace-fail "Terminal=true" "Terminal=false" \
          --replace-fail "Comment=Manage bluethooth device" "Comment=Manage bluetooth devices"
      ''
    ))
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.windowRules."bluetui" = lib.${ns}.mkHyprlandCenterFloatRule "bluetui" 60 60;
  };

  ns.persistence.directories = [ "/var/lib/bluetooth" ];
}
