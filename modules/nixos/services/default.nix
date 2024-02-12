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

    syncthing = {
      enable = mkEnableOption "syncthing";
      server = mkOption {
        type = types.bool;
        description = ''
          Whether to act as the main syncthing server and share folders. Only
          one device in a syncthing network should have this enabled.
        '';
        default = false;
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
        description = "jellyfin service autostart";
        default = true;
      };
    };

    udisks2.enable = mkEnableOption "udisks2";
    wireguard.enable = mkEnableOption "wireguard";

    ollama = {
      enable = mkEnableOption "ollama";
      autoStart = mkEnableOption "ollama service autostart";
    };

    broadcast-box = {
      enable = mkEnableOption "broadcast box";
      autoStart = mkEnableOption "broadcast box service autostart";
    };

  };

  config = {
    services.udisks2.enable = config.modules.services.udisks2.enable;
  };
}
