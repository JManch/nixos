{
  lib,
  config,
  username,
  adminUsername,
  ...
}:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    optional
    mapAttrsToList
    all
    allUnique
    ;
  inherit (lib.${ns}) scanPaths asserts;
  cfg = config.${ns}.system;
in
{
  imports = scanPaths ./.;

  options.${ns}.system = {
    ssh = {
      server.enable = mkEnableOption "SSH server";
      agent.enable = mkEnableOption "SSH authentication agent" // {
        default = username == adminUsername;
      };
    };

    impermanence.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable impermanence. /persist will be used for the
        persistent filesystem.
      '';
    };

    reservedIDs = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            uid = mkOption { type = types.int; };
            gid = mkOption { type = types.int; };
          };
        }
      );
      default = { };
      description = ''
        Manually allocated UIDs and GIDs for users. IDs must be > 1000 to
        prevent clashing with dynamically allocated system users. This option
        must be unconditionally set regardless of whether or not the associated
        module is enabled.
      '';
    };

    virtualisation = {
      libvirt.enable = mkEnableOption "libvirt virtualisation";

      vmVariant = mkOption {
        type = types.bool;
        internal = true;
        default = false;
      };

      mappedTCPPorts = mkOption {
        type = with types; listOf (attrsOf port);
        default = [ ];
        example = [
          {
            vmPort = 8999;
            hostPort = 9003;
          }
        ];
        description = ''
          Map TCP ports from VM to host. Forceful alternative to opening the
          firewall as it does not attempt to avoid clashes by mapping port into
          50000-65000 range.
        '';
      };

      mappedUDPPorts = mkOption {
        type = with types; listOf (attrsOf port);
        default = [ ];
        example = [
          {
            vmPort = 8999;
            hostPort = 9003;
          }
        ];
        description = ''
          Map UDP ports from VM to host. Forceful alternative to opening the
          firewall as it does not attempt to avoid clashes by mapping port into
          50000-65000 range.
        '';
      };
    };

    networking = {
      useNetworkd =
        mkEnableOption ''
          Whether to enable systemd-networkd network configuration.
        ''
        // {
          default = true;
        };

      tcpOptimisations = mkEnableOption "TCP optimisations";
      resolved.enable = mkEnableOption "Resolved";

      wiredInterface = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "enp5s0";
        description = ''
          Wired network interface of the device. Be careful to use the main
          interface name displayed in `ip a`, NOT the altname.
        '';
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
        enable = mkEnableOption "Firewall" // {
          default = true;
        };

        defaultInterfaces = mkOption {
          type = types.listOf types.str;
          default = optional (cfg.networking.wiredInterface != null) cfg.networking.wiredInterface;
          example = [
            "eno1"
            "wlp6s0"
          ];
          description = ''
            List of interfaces to which default firewall rules should be applied.
          '';
        };
      };

      vlans = mkOption {
        type = types.attrsOf types.attrs;
        default = { };
        description = ''
          Attribute set where the keys are VLAN IDs and the values are the
          VLAN's network config. The VLANs will the added to the primary
          interface.
        '';
      };
    };

    audio = {
      enable = mkEnableOption "Pipewire audio";
      extraAudioTools = mkEnableOption "extra audio tools including Easyeffects and Helvum";
      inputNoiseSuppression = mkEnableOption "input noise suppression source";

      alsaDeviceAliases = mkOption {
        type = with types; attrsOf str;
        default = { };
        description = ''
          Attribute set of alsa devices to rename where the name is the
          original name and the value is the new name. The original name can be
          found using `pamixer --list-sinks` or `pamixer --list-sources`.
        '';
      };

      defaultSink = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "System default audio sink name from `pactl list short sinks`";
      };

      defaultSource = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "System default audio source name from `pactl list short sources`";
      };

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
      bootEntry = {
        enable = mkEnableOption "Windows systemd-boot boot entry";

        fsAlias = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The fs alias of the windows partition";
        };
      };
    };
  };

  config = {
    assertions =
      let
        gids = mapAttrsToList (name: value: value.gid) cfg.reservedIDs;
        uids = mapAttrsToList (name: value: value.uid) cfg.reservedIDs;
      in
      asserts [
        (allUnique uids)
        "Reserved UIDs must be unique"
        (allUnique gids)
        "Reserved GIDs must be unique"
        (all (uid: uid > 1000 && uid < 2000) uids)
        "Reserved UIDs must be greater than 1000 and less than 2000"
        (all (gid: gid > 1000 && gid < 2000) gids)
        "Reserved GIDs must be greater than 1000 and less than 2000"
      ];
  };
}
