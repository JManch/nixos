{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf mkVMOverride optionalString utils;
  inherit (config.device) gpu ipAddress;
  inherit (config.modules.system.networking) publicPorts;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.frigate;
in
mkIf cfg.enable
{
  modules.services.frigate.rtspAddress = { channel, subtype, go2rtc ? false }:
    "rtsp://${optionalString go2rtc "$"}{FRIGATE_RTSP_USER}:${optionalString go2rtc "$"}{FRIGATE_RTSP_PASSWORD}@${cfg.nvrAddress}:554/cam/realmonitor?channel=${toString channel}&subtype=${toString subtype}";

  users.groups.cctv.members = [ "frigate" "go2rtc" ];

  # TODO: (waiting on home assistance module)
  # - Setup mqtt host... should probably do this on the hass side?
  # - Test secrets work
  networking.hosts.${cfg.nvrAddress} = [ "cctv" ];

  services.frigate = {
    enable = true;
    hostname = "frigate.internal.com";

    settings = {
      ffmpeg.hwaccel_args = mkIf (gpu.type == "amd") "preset-vaapi";

      # TODO: Move this to home assistant config
      mqtt = {
        enabled = true;
        # TODO: Set mqtt host
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
            "0,576,213,576,134,370,242,331,422,158,420,101,540,96,546,149,769,195,605,264,640,408,356,576,1024,576,1024,0,0,0"
          ];
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
            "1024,0,1024,264,721,262,721,576,0,576,0,0"
          ];
        };
      };

      detect = {
        enabled = true;
        width = 1024; # The source cam is 704 but we stretch it
        height = 576;
      };

      objects.track = [
        "person"
        "car"
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
    UMask = "0027";
    EnvironmentFile = config.age.secrets.cctvVars.path;
  };

  systemd.services.nginx.serviceConfig = {
    SocketBindDeny = publicPorts;
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

      webrtc = {
        listen = ":8555";
        candidates = [
          "${ipAddress}:8555"
          "stun:8555"
        ];
      };

      # TODO: When implementing home assistant need to configure this
      # Frigate sets it to "/config" but I am not sure if this is correct?
      # hass.config = "/config";

      streams = {
        driveway = (cfg.rtspAddress { channel = 2; subtype = 0; go2rtc = true; });
        poolhouse = (cfg.rtspAddress { channel = 1; subtype = 0; go2rtc = true; });
      };

      # We not using ffmpeg sources so hardware acceleration isn't needed
      # https://github.com/AlexxIT/go2rtc/wiki/Hardware-acceleration
    };
  };

  systemd.services.go2rtc.serviceConfig = {
    EnvironmentFile = config.age.secrets.cctvVars.path;
    SocketBindDeny = publicPorts;
  };

  # Because WebRTC port has to be forwarded
  modules.system.networking.publicPorts = [ 8555 ];

  services.nginx.virtualHosts.${config.services.frigate.hostname}.listen = [{
    addr = "127.0.0.1";
    port = 5000;
  }];

  services.caddy.virtualHosts."cctv.${fqDomain}".extraConfig = ''
    import lan_only
    reverse_proxy http://127.0.0.1:5000
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
      port = 5000;
    }];

    # NOTE: I can't get the WebRTC stream to work from the VM
    networking.firewall.allowedTCPPorts = [ 5000 1984 8554 ];
    networking.firewall.allowedUDPPorts = [ 8554 ];
  };
}
