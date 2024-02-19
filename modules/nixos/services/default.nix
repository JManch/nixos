{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types literalExpression;
  cfg = config.modules.services;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {
    udisks.enable = mkEnableOption "udisks";
    wireguard.enable = mkEnableOption "WireGuard";

    greetd = {
      enable = mkEnableOption "Greetd with TUIgreet";

      launchCmd = mkOption {
        type = types.str;
        default = "";
        description = "Login launch command";
        example = literalExpression "lib.getExe pkgs.hyprland";
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
      assertion = cfg.greetd.enable -> (cfg.greetd.launchCmd != "");
      message = "Greetd launch command must be set";
    }];
  };
}
