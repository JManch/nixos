{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {

    greetd = {
      enable = mkEnableOption "greetd with tuigreet";
      launchCmd = mkOption {
        type = types.str;
        description = "Login launch command";
        example = "Hyprland";
      };
    };

    wgnord = {
      enable = mkEnableOption "wgnord";
      country = mkOption {
        type = types.str;
        description = "The country to VPN to";
        default = "Switzerland";
      };
    };

    jellyfin = {
      enable = mkEnableOption "jellyfin";
      autoStart = mkOption {
        type = types.bool;
        description = "jellyfin service auto start";
        default = true;
      };
    };

    udisks2.enable = mkEnableOption "udisks2";
    wireguard.enable = mkEnableOption "wireguard";

    ollama = {
      enable = mkEnableOption "ollama";
      autoStart = mkEnableOption "ollama service auto start";
    };

    broadcast-box = {
      enable = mkEnableOption "broadcast box";
      autoStart = mkEnableOption "broadcast box service auto start";
    };

  };

  config = {
    services.udisks2.enable = config.modules.services.udisks2.enable;
  };
}
