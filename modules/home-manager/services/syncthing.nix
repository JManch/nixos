{
  lib,
  cfg,
  config,
  vmVariant,
}:
let
  inherit (lib) optional;
  inherit (config.home) username;
in
{
  conditions = [ (!vmVariant) ];

  opts = with lib; {
    exposeWebGUI = mkEnableOption "exposing the web GUI";

    port = mkOption {
      type = types.port;
      default = 8384;
      description = "Web GUI listening port";
    };
  };

  services.syncthing = {
    enable = true;
    extraOptions = [
      "--home=${config.xdg.configHome}/syncthing"
      "--no-default-folder"
      "--gui-address=${if cfg.exposeWebGUI then "0.0.0.0" else "127.0.0.1"}:${toString cfg.port}"
    ];
  };

  systemd.user.services.syncthing = {
    Unit = {
      Requires = [ "home-${username}-.config-syncthing.mount" ];
      After = [ "home-${username}-.config-syncthing.mount" ];
      X-SwitchMethod = "keep-old";
    };
  };

  nsConfig = {
    firewall.allowedTCPPorts = [ 22000 ] ++ optional cfg.exposeWebGUI cfg.port;
    firewall.allowedUDPPorts = [
      22000
      21027
    ];

    persistence.directories = [ ".config/syncthing" ];
  };
}
