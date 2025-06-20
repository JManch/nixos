{ lib, cfg }:
let
  inherit (lib) mkForce optional mkEnableOption;
in
{
  opts.autoStart = mkEnableOption "Waydroid auto start";

  virtualisation.waydroid.enable = true;
  systemd.services."waydroid-container".wantedBy = mkForce (
    optional cfg.autoStart "multi-user.target"
  );

  ns.persistence.directories = [ "/var/lib/waydroid" ];
  ns.persistenceHome.directories = [ ".local/share/waydroid" ];
}
