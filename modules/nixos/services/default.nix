{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.modules.services;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {
    udisks.enable = mkEnableOption "udisks";
    wireguard.enable = mkEnableOption "WireGuard";

    greetd = {
      enable = mkEnableOption "Greetd with TUIgreet";

      sessionDirs = mkOption {
        type = types.listOf types.str;
        apply = builtins.concatStringsSep ":";
        default = [ ];
        description = "Directories that contain .desktop files to be used as session definitions";
      };
    };

    wgnord = {
      enable = mkEnableOption "Wireguard NordVPN";

      country = mkOption {
        type = types.str;
        default = "Switzerland";
        description = "The country to VPN to";
      };
    };

    jellyfin = {
      enable = mkEnableOption "Jellyfin";

      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = "Jellyfin service auto start";
      };
    };

    ollama = {
      enable = mkEnableOption "Ollama";
      autoStart = mkEnableOption "Ollama service auto start";
    };

    broadcast-box = {
      enable = mkEnableOption "Broadcast Box";
      autoStart = mkEnableOption "Broadcast Box service auto start";
    };
  };

  config = {
    services.udisks2.enable = config.modules.services.udisks.enable;

    assertions = [{
      assertion = cfg.greetd.enable -> (cfg.greetd.sessionDirs != [ ]);
      message = "Greetd session dirs must be set";
    }];
  };
}
