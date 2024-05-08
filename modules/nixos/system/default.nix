{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.system = {
    bluetooth.enable = mkEnableOption "bluetooth";

    virtualisation = {
      libvirt.enable = mkEnableOption "libvirt virtualisation";
      containerisation.enable = mkEnableOption "containerisation virtualisation";
      microvm.enable = mkEnableOption "microvm virtual machines";

      vmVariant = mkOption {
        type = types.bool;
        internal = true;
        default = false;
      };

      mappedTCPPorts = mkOption {
        type = types.listOf (types.attrsOf types.port);
        default = [ ];
        example = [{ vmPort = 8999; hostPort = 9003; }];
        description = ''
          Map TCP ports from VM to host. Forceful alternative to opening the
          firewall as it does not attempt to avoid clashes by mapping port into
          50000-65000 range.
        '';
      };

      mappedUDPPorts = mkOption {
        type = types.listOf (types.attrsOf types.port);
        default = [ ];
        example = [{ vmPort = 8999; hostPort = 9003; }];
        description = ''
          Map UDP ports from VM to host. Forceful alternative to opening the
          firewall as it does not attempt to avoid clashes by mapping port into
          50000-65000 range.
        '';
      };
    };

    ssh.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable ssh server";
    };

    networking = {
      tcpOptimisations = mkEnableOption "TCP optimisations";
      resolved.enable = mkEnableOption "Resolved";

      primaryInterface = mkOption {
        type = types.str;
        example = "eno1";
        description = "Primary wired network interface of the device";
      };

      staticIPAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Disable DHCP and assign the device a static IPV4 address. Remember to
          include the network's subnet mask.
        '';
      };

      defaultGateway = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Default gateway of the device's primary local network.
        '';
      };

      wireless = {
        enable = mkEnableOption "wireless";

        interface = mkOption {
          type = types.str;
          example = "wlp6s0";
        };

        disableOnBoot = mkEnableOption ''
          disabling of wireless on boot. Use `rfkill unblock wifi` to manually enable.
        '';
      };

      firewall = {
        enable = mkEnableOption "Firewall";
        defaultInterfaces = mkOption {
          type = types.listOf types.str;
          default = [ config.modules.system.networking.primaryInterface ];
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
