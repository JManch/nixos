{
  lib,
  cfg,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    optional
    mkEnableOption
    ;
  inherit (config.${ns}.core) home-manager;
in
{
  opts.autoStart = mkEnableOption "Waydroid auto start";

  virtualisation.waydroid.enable = true;
  systemd.services."waydroid-container".wantedBy = mkForce (
    optional cfg.autoStart "multi-user.target"
  );

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.settings.windowrule = [
      "float, class:^(Waydroid)$"
      "center, class:^(Waydroid)$"
      "keepaspectratio, class:^(Waydroid)$"
    ];
  };

  ns.persistence.directories = [ "/var/lib/waydroid" ];
  ns.persistenceHome.directories = [ ".local/share/waydroid" ];
}
