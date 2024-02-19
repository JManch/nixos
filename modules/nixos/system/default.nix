{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.system = {
    bluetooth.enable = mkEnableOption "bluetooth";
    virtualisation.enable = mkEnableOption "virtualisation";

    ssh = {
      allowPasswordAuth = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable ssh password authentication";
      };
    };

    networking = {
      tcpOptimisations = mkEnableOption "TCP optimisations";
      resolved.enable = mkEnableOption "Resolved";
      wireless.enable = mkEnableOption "wireless";

      firewall = {
        enable = mkEnableOption "Firewall";
        defaultInterfaces = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "eno1" "wlp6s0" ];
          description = ''
            List of interfaces to which default firewall rules should be applied.
          '';
        };
      };
    };

    audio = {
      enable = mkEnableOption "Pipewire audio";
      extraAudioTools = mkEnableOption "extra audio tools including Easyeffects and Helvum";
      scripts = {
        toggleMic = mkOption {
          type = types.str;
          readOnly = true;
          description = "Script for toggling microphone mute";
        };
      };
    };

    windows = {
      enable = mkEnableOption "features for systems dual-booting Window";
      bootEntry = mkEnableOption "Windows systemd-boot boot entry";
    };
  };
}
