{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.system = {

    ssh = {
      allowPasswordAuth = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable ssh password authentication";
      };
    };

    networking = {
      tcpOptimisations = mkEnableOption "TCP optimisations";
      firewall = {
        enable = mkEnableOption "firewall";
        defaultInterfaces = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "eno1" "wlp6s0" ];
          description = ''
            List of interfaces to which default firewall rules should be applied.
          '';
        };
      };
      resolved.enable = mkEnableOption "Resolved";
      wireless.enable = mkEnableOption "wireless";
    };

    bluetooth.enable = mkEnableOption "bluetooth";

    audio = {
      enable = mkEnableOption "Pipewire audio";
      extraAudioTools = mkEnableOption "extra audio tools including Easyeffects and Helvum";
      scripts = {
        toggleMic = mkOption {
          type = types.str;
          description = "Script for toggling microphone mute";
        };
      };
    };

    virtualisation = {
      enable = mkEnableOption "virtualisation";
    };

    windows = {
      enable = mkEnableOption "enable features for systems dual-booting windows";
      bootEntry = mkEnableOption "create a windows systemd-boot boot entry";
    };

  };
}
