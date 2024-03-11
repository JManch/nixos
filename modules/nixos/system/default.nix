{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.system = {
    bluetooth.enable = mkEnableOption "bluetooth";
    virtualisation.enable = mkEnableOption "virtualisation";

    ssh.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable ssh server";
    };

    networking = {
      tcpOptimisations = mkEnableOption "TCP optimisations";
      resolved.enable = mkEnableOption "Resolved";
      forceNoDHCP = mkEnableOption "forceful disabling of DHCP";

      wireless = {
        enable = mkEnableOption "wireless";
        disableOnBoot = mkEnableOption ''
          disabling of wireless on boot. Use `rfkill unblock wifi` to manually enable.";
        '';
      };

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

      publicPorts = mkOption {
        type = types.listOf types.port;
        default = [ ];
        description = ''
          List of ports that are both exposed in the firewall and port
          forwarded to the internet. Used to block access to these ports from
          all systemd services that shouldn't bind to them.
        '';
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
