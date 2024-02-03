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
      firewall.enable = mkEnableOption "firewall";
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

    windowsBootEntry = {
      enable = mkEnableOption "Windows boot menu entry";
      bootstrap = mkEnableOption "enable bootstrapping of the windows boot entry by adding an edk2 shell boot entry";
    };

  };
}
