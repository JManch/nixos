{ lib
, config
, ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [
    ./greetd.nix
    ./syncthing.nix
    ./wgnord.nix
    ./wireguard.nix
    ./jellyfin.nix
  ];

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
      autostart = mkOption {
        type = types.bool;
        default = true;
      };
    };

    udisks2.enable = mkEnableOption "udisks2";
    wireguard.enable = mkEnableOption "wireguard";

  };

  config = {
    services.udisks2.enable = config.modules.services.udisks2.enable;
  };
}
