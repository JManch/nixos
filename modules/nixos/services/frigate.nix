{ lib
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf mkVMOverride optionalString utils optional;
  inherit (config.device) ipAddress;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.modules.services) hass mosquitto caddy;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (config.age.secrets) cctvVars mqttFrigatePassword;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.frigate;
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    (hostname == "homelab")
    "Frigate is only intended to work on host 'homelab'"
    caddy.enable
    "Frigate requires Caddy to be enabled"
    (cfg.nvrAddress != "")
    "The Frigate service requires nvrAddress to be set"
    config.hardware.opengl.enable
    "The Frigate service requires hardware acceleration. Set `hardware.opengl.enable`."
  ];

  modules.services.frigate.rtspAddress = { channel, subtype, go2rtc ? false }:
    "rtsp://${optionalString go2rtc "$"}{FRIGATE_RTSP_USER}:${optionalString go2rtc "$"}{FRIGATE_RTSP_PASSWORD}@${cfg.nvrAddress}:554/cam/realmonitor?channel=${toString channel}&subtype=${toString subtype}";

  users.groups.cctv.members = [ "frigate" "go2rtc" ];

  networking.hosts.${cfg.nvrAddress} = [ "cctv" ];

  services.frigate = {
    enable = true;
    hostname = "frigate.internal.com";

    settings = {
      ffmpeg.hwaccel_args = "preset-vaapi";

      mqtt = mkIf (hass.enable && mosquitto.enable) {
        enabled = true;
        host = "127.0.0.1";
        port = mosquitto.port;
        user = "{FRIGATE_MQTT_USER}";
        password = "{FRIGATE_MQTT_PASSWORD}";
      };

      # This is not actually used because we run a seperate instance of go2rtc
      # but without it frigate doesn't show the mse and webrtc streams in the
      # web interface. Frigate actually uses go2rtc for those streams rather
      # than the camera RTSP stream.
      go2rtc.streams = {
        driveway = (cfg.rtspAddress { channel = 2; subtype = 0; go2rtc = true; });
        poolhouse = (cfg.rtspAddress { channel = 1; subtype = 0; go2rtc = true; });
      };

      cameras = {
        driveway = {
          ffmpeg.inputs = [
            {
              # It's possible to use the go2rtc restream as a source here
              # however on low-powered devices it's actually more intensive
              # because go2rtc adds overhead. I'd rather have the extra cam
              # connections which 99% of the time will just be 1 for the detect
              # stream.
              path = (cfg.rtspAddress { channel = 2; subtype = 0; });
              roles = [ "record" ];
            }
            {
              path = (cfg.rtspAddress { channel = 2; subtype = 1; });
              roles = [ "detect" ];
            }
          ];

          motion.mask = [
            "0,576,173,576,63,306,199,262,416,149,418,43,549,34,543,126,802,176,626,264,630,407,356,576,1024,576,1024,0,0,0"
          ];

          zones.entrance = {
            coordinates = "543,66,548,119,591,134,501,148,408,157,411,76";
            objects = [ "person" ];
          };
        };

        poolhouse = {
          ffmpeg.inputs = [
            {
              path = (cfg.rtspAddress { channel = 1; subtype = 0; });
              roles = [ "record" ];
            }
            {
              path = (cfg.rtspAddress { channel = 1; subtype = 1; });
              roles = [ "detect" ];
            }
          ];

          motion.mask = [
            "1024,0,1024,576,804,576,804,434,942,387,939,271,742,262,744,327,804,328,804,576,0,576,0,0"
          ];
        };
      };

      motion = {
        threshold = 60;
        contour_area = 50;
      };

      detect = {
        enabled = true;
        width = 1024; # The source cam is 704 but we stretch it
        height = 576;
      };

      objects.track = [
        "person"
      ];

      record = {
        enabled = true;
        events.retain = {
          default = 10;
          mode = "active_objects";
        };
      };

      snapshots.enabled = true;
    };
  };

  systemd.services.frigate.serviceConfig = utils.hardeningBaseline config {
    # WARN: The upstream module tries to set a read only bind path with BindPaths
    # which is invalid, I'm not sure if it affects functionality?
    DynamicUser = false;
    ProtectProc = "default";
    ProcSubset = "all";
    SystemCallFilter = [ "@system-service" "~@privileged" ];
    # Device access for hw accel
    PrivateDevices = false;
    DeviceAllow = [ ];
    UMask = "0027";
    EnvironmentFile = cctvVars.path;
  };

  # Nginx upstream module has good systemd hardening
  systemd.services.nginx.serviceConfig = {
    SocketBindDeny = publicPorts;
  };

  modules.services.mosquitto.users = {
    frigate = {
      acl = [ "readwrite #" ];
      hashedPasswordFile = mqttFrigatePassword.path;
    };
  };

  # We just use go2rtc to provide a low latency WebRTC stream. It is lazy so
  # won't use resources if nobody is requesting the stream. We do not use the
  # go2rtc restreams in Frigate because it adds unnecessary overhead on
  # low-powered devices. Frigate uses go2rtc for displaying the mse and webrtc
  # streams in the web-interface.
  services.go2rtc = {
    enable = true;

    # Useful reference for emulating what frigate sets as default go2rtc config
    # https://github.com/blakeblackshear/frigate/blob/dev/docker/main/rootfs/usr/local/go2rtc/create_config.py
    settings = {
      api = {
        listen = "127.0.0.1:1984";
        origin = "*";
      };

      rtsp = {
        listen = "127.0.0.1:8554";
        default_query = "mp4";
      };

      webrtc = mkIf cfg.webrtc.enable {
        listen = ":${toString cfg.webrtc.port}";
        candidates = [
          "${ipAddress}:${toString cfg.webrtc.port}"
          # "stun" here translates to Google's STUN server in the go2rtc code
          # https://github.com/AlexxIT/go2rtc/blob/5fa31fe4d6cf0e77562b755d52e8ed0165f89d25/internal/webrtc/candidates.go#L21
          # https://github.com/AlexxIT/go2rtc/blob/5fa31fe4d6cf0e77562b755d52e8ed0165f89d25/pkg/webrtc/helpers.go#L170
          "stun:${toString cfg.webrtc.port}"
        ];
      };

      streams = {
        driveway = (cfg.rtspAddress { channel = 2; subtype = 0; go2rtc = true; });
        poolhouse = (cfg.rtspAddress { channel = 1; subtype = 0; go2rtc = true; });
      };

      # We not using ffmpeg sources so hardware acceleration isn't needed
      # https://github.com/AlexxIT/go2rtc/wiki/Hardware-acceleration
    };
  };

  systemd.services.go2rtc.serviceConfig = utils.hardeningBaseline config {
    EnvironmentFile = cctvVars.path;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    SystemCallFilter = [ "@system-service" "~@privileged" ];
    SocketBindDeny = "any";
    SocketBindAllow = [ 8554 1984 ] ++ optional cfg.webrtc.enable cfg.webrtc.port;
    # go2rtc sometimes randomly crashes
    Restart = "on-failure";
    RestartSec = 10;
  };

  # Always consider a public port because of router forwarding rule
  modules.system.networking.publicPorts = [ cfg.webrtc.port ];
  networking.firewall = mkIf cfg.webrtc.enable {
    allowedTCPPorts = cfg.webrtc.port;
    allowedUDPPorts = cfg.webrtc.port;
  };

  services.nginx.virtualHosts.${config.services.frigate.hostname}.listen = [{
    addr = "127.0.0.1";
    port = cfg.port;
  }];

  services.caddy.virtualHosts."cctv.${fqDomain}".extraConfig = ''
    ${allowAddresses trustedAddresses}
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  persistence.directories = [{
    directory = "/var/lib/frigate";
    user = "frigate";
    group = "frigate";
    mode = "700";
  }];

  virtualisation.vmVariant = {
    services.frigate.settings = {
      mqtt.enabled = mkVMOverride false;
      detect.enabled = mkVMOverride false;
      record.enabled = mkVMOverride false;
      snapshots.enabled = mkVMOverride false;
    };

    services.go2rtc.settings = {
      api.listen = mkVMOverride ":1984";
      rtsp.listen = mkVMOverride ":8554";
    };

    services.nginx.virtualHosts.${config.services.frigate.hostname}.listen = mkVMOverride [{
      addr = "0.0.0.0";
      port = cfg.port;
    }];

    # NOTE: I can't get the WebRTC stream to work from the VM
    networking.firewall.allowedTCPPorts = [ cfg.port 1984 8554 ];
    networking.firewall.allowedUDPPorts = [ 8554 ];
  };
}
