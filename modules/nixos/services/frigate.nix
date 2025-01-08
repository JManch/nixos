{
  lib,
  config,
  hostname,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    mkVMOverride
    optionalString
    optional
    singleton
    ;
  inherit (lib.${ns}) asserts hardeningBaseline;
  inherit (config.${ns}.device) ipAddress;
  inherit (config.${ns}.services) hass mosquitto caddy;
  inherit (config.age.secrets) cctvVars mqttFrigatePassword;
  cfg = config.${ns}.services.frigate;
  port = 5000;
in
mkIf cfg.enable {
  assertions = asserts [
    (hostname == "homelab")
    "Frigate is only intended to work on host 'homelab'"
    caddy.enable
    "Frigate requires Caddy to be enabled"
    (cfg.nvrAddress != "")
    "The Frigate service requires nvrAddress to be set"
    config.hardware.graphics.enable
    "The Frigate service requires hardware acceleration"
  ];

  ${ns} = {
    services = {
      frigate.rtspAddress =
        {
          channel,
          subtype,
          go2rtc ? false,
        }:
        "rtsp://${optionalString go2rtc "$"}{FRIGATE_RTSP_USER}:${optionalString go2rtc "$"}{FRIGATE_RTSP_PASSWORD}@${cfg.nvrAddress}:554/cam/realmonitor?channel=${toString channel}&subtype=${toString subtype}";

      mosquitto.users = mkIf (hass.enable && mosquitto.enable) {
        frigate = {
          acl = [ "readwrite #" ];
          hashedPasswordFile = mqttFrigatePassword.path;
        };
      };

      caddy.virtualHosts.cctv.extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString port}
      '';

      caddy.virtualHosts.go2rtc.extraConfig = ''
        reverse_proxy http://127.0.0.1:1984
      '';
    };
  };

  users.groups.cctv.members = [
    "frigate"
    "go2rtc"
  ];

  networking.hosts.${cfg.nvrAddress} = [ "cctv" ];

  services.frigate = {
    enable = true;
    hostname = "frigate.internal.com";

    settings = {
      auth.enabled = false;
      tls.enabled = false;
      ffmpeg.hwaccel_args = "preset-vaapi";

      detectors = mkIf cfg.coral.enable {
        coral = {
          type = "edgetpu";
          device = cfg.coral.type;
        };
      };

      mqtt = mkIf (hass.enable && mosquitto.enable) {
        enabled = true;
        host = "127.0.0.1";
        port = 1883;
        user = "{FRIGATE_MQTT_USER}";
        password = "{FRIGATE_MQTT_PASSWORD}";
      };

      # This is not actually used because we run a seperate instance of go2rtc
      # but without it frigate doesn't show the mse and webrtc streams in the
      # web interface. Frigate actually uses go2rtc for those streams rather
      # than the camera RTSP stream.
      go2rtc.streams = {
        driveway = cfg.rtspAddress {
          channel = 2;
          subtype = 0;
          go2rtc = true;
        };

        poolhouse = cfg.rtspAddress {
          channel = 1;
          subtype = 0;
          go2rtc = true;
        };
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
              path = cfg.rtspAddress {
                channel = 2;
                subtype = 0;
              };
              roles = [ "record" ];
            }
            {
              path = cfg.rtspAddress {
                channel = 2;
                subtype = 1;
              };
              roles = [ "detect" ];
            }
          ];

          motion.mask = [
            "0,576,173,576,63,306,199,262,416,149,418,43,549,34,548,117,690,136,775,98,903,132,643,264,679,320,619,378,356,576,1024,576,1024,0,0,0"
          ];

          zones.entrance.coordinates = "0.535,0.177,0.569,0.233,0.411,0.256,0.405,0.191";
          zones.entrance.inertia = 1;
          # Disabling this because it seems reduce detection rates
          # review.alerts.required_zones = [ "entrance" ];

          # I feel like this zone shouldn't be necessary as I'd expect all
          # events in non-alert zones to be treated as detections but
          # detections don't work without this...
          # zones.driveway-zone.coordinates = "0,0.063,0.41,0.253,0.569,0.229,1,0.088,1,1,0,1";
          # review.detections.required_zones = [ "driveway-zone" ];

          objects.filters.car.mask = [ "0.633,0,0.633,0.08,0.409,0.089,0.406,0.28,0.621,0.479,1,1,0,1,0,0" ];
        };

        poolhouse = {
          ffmpeg.inputs = [
            {
              path = cfg.rtspAddress {
                channel = 1;
                subtype = 0;
              };
              roles = [ "record" ];
            }
            {
              path = cfg.rtspAddress {
                channel = 1;
                subtype = 1;
              };
              roles = [ "detect" ];
            }
          ];

          motion.mask = [
            "1024,0,1024,445,994,411,981,309,951,262,860,252,752,249,749,305,811,313,810,408,661,496,537,492,282,456,0,453,0,0"
          ];

          objects.filters.car.mask = [ "1024,576,0,576,0,306,1024,316" ];
        };
      };

      motion = {
        threshold = 30;
        contour_area = 10;
      };

      detect = {
        enabled = true;
        width = 1024; # The source cam is 704 but we stretch it
        height = 576;
      };

      review.alerts.labels = [
        "person"
        "car"
        "cat"
      ];

      objects.track = [
        "person"
        "car"
        "cat"
      ];

      record = {
        enabled = true;
        events.retain = {
          default = 10;
          mode = "motion";
        };
      };

      snapshots.enabled = true;
    };
  };

  systemd.services.frigate.serviceConfig = hardeningBaseline config {
    DynamicUser = false;
    ProtectProc = "default";
    ProcSubset = "all";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
    # Device access for hw accel
    PrivateDevices = false;
    DeviceAllow = [ ];
    UMask = "0027";
    EnvironmentFile = cctvVars.path;
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
        # Use a fixed UDP port to simplify firewall rules Don't need to
        # publically expose these ports since we use VPN
        listen = ":${toString cfg.webrtc.port}";

        candidates = [
          "${ipAddress}:${toString cfg.webrtc.port}"
          # If using "stun" here it translates to Google's STUN server
          # "${inputs.nix-resources.secrets.mikrotikDDNS}:${toString cfg.webrtc.port}"
        ];
      };

      streams = {
        driveway = (
          cfg.rtspAddress {
            channel = 2;
            subtype = 0;
            go2rtc = true;
          }
        );
        poolhouse = (
          cfg.rtspAddress {
            channel = 1;
            subtype = 0;
            go2rtc = true;
          }
        );
      };

      # We not using ffmpeg sources so hardware acceleration isn't needed
      # https://github.com/AlexxIT/go2rtc/wiki/Hardware-acceleration
    };
  };

  systemd.services.go2rtc.serviceConfig = hardeningBaseline config {
    EnvironmentFile = cctvVars.path;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
    ];
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
    SocketBindDeny = "any";
    SocketBindAllow = [
      8554
      1984
      5353 # for mDNS
    ] ++ optional cfg.webrtc.enable cfg.webrtc.port;
    # go2rtc sometimes randomly crashes
    Restart = "on-failure";
    RestartSec = 10;
  };

  networking.firewall = mkIf cfg.webrtc.enable {
    allowedTCPPorts = [ cfg.webrtc.port ];
    allowedUDPPorts = [ cfg.webrtc.port ];
  };

  services.nginx.virtualHosts.${config.services.frigate.hostname} = {
    listen = singleton {
      addr = "127.0.0.1";
      port = port;
    };

    extraConfig = mkForce ''
      # vod settings
      vod_base_url "";
      vod_segments_base_url "";
      vod_mode mapped;
      vod_max_mapping_response_size 1m;
      vod_upstream_location /api;
      vod_align_segments_to_key_frames on;
      vod_manifest_segment_durations_mode accurate;
      vod_ignore_edit_list on;
      vod_segment_duration 10000;
      vod_hls_mpegts_align_frames off;
      vod_hls_mpegts_interleave_frames on;

      # file handle caching / aio
      open_file_cache max=1000 inactive=5m;
      open_file_cache_valid 2m;
      open_file_cache_min_uses 1;
      open_file_cache_errors on;
      aio on;

      # https://github.com/kaltura/nginx-vod-module#vod_open_file_thread_pool
      vod_open_file_thread_pool default;

      # vod caches
      vod_metadata_cache metadata_cache 512m;
      vod_mapping_cache mapping_cache 5m 10m;

      # gzip manifest
      gzip_types application/vnd.apple.mpegurl;
    '';
  };

  persistence.directories = singleton {
    directory = "/var/lib/frigate";
    user = "frigate";
    group = "frigate";
    mode = "0750";
  };

  virtualisation.vmVariant = {
    services.frigate.settings = {
      mqtt.enabled = mkVMOverride false;
      detect.enabled = mkVMOverride false;
      record.enabled = mkVMOverride false;
      snapshots.enabled = mkVMOverride false;
      ffmpeg.hwaccel_args = mkVMOverride null;
    };

    services.go2rtc.settings = {
      api.listen = mkVMOverride ":1984";
      rtsp.listen = mkVMOverride ":8554";
    };

    services.nginx.virtualHosts.${config.services.frigate.hostname}.listen = mkVMOverride (singleton {
      inherit port;
      addr = "0.0.0.0";
    });

    # NOTE: I can't get the WebRTC stream to work from the VM
    networking.firewall.allowedTCPPorts = [
      port
      1984
      8554
    ];
    networking.firewall.allowedUDPPorts = [ 8554 ];
  };
}
