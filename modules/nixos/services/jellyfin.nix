{ lib, config, ... }:
let
  cfg = config.modules.services.jellyfin;
in
lib.mkIf cfg.enable
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  systemd.services.jellyfin.wantedBy = lib.lists.optional cfg.autostart [ "multi-user.target" ];
}
