{ lib, pkgs, config, inputs, ... }:
let
  inherit (lib) mkIf mkVMOverride;
  cfg = config.modules.services.frigate;
in
mkIf cfg.enable
{
  networking.hosts.${cfg.nvrAddress} = [ "cctv" ];

  services.frigate = {
    enable = true;
    settings = {
      mqtt = {
        enabled = true;
        # TODO: Set mqtt host
        user = "{FRIGATE_MQTT_USER}";
        password = "{FRIGATE_MQTT_PASSWORD}";
      };

      go2rtc.streams = {
        driveway = [
          (cfg.rtspAddress 2 0)
        ];
        poolhouse = [
          (cfg.rtspAddress 1 0)
        ];
      };

      cameras = {
        driveway = {
          ffmpeg.inputs = [
            {
              path = (cfg.rtspAddress 2 0);
              roles = [ "record" ];
            }

            {
              path = (cfg.rtspAddress 2 1);
              roles = [ "detect" ];
            }
          ];

          detect = {
            enabled = true;
            width = 1024; # The source cam is 704 but we stretch it
            height = 576;
          };

          motion.mask = [
            "0,576,213,576,134,370,242,331,422,158,420,101,540,96,546,149,769,195,605,264,640,408,356,576,1024,576,1024,0,0,0"
          ];
        };

        poolhouse = {
          ffmpeg.inputs = [
            {
              path = (cfg.rtspAddress 1 0);
              roles = [ "record" ];
            }

            {
              path = (cfg.rtspAddress 1 1);
              roles = [ "detect" ];
            }
          ];

          detect = {
            enabled = true;
            width = 1024; # The source cam is 704 but we stretch it
            height = 576;
          };

          motion.mask = [
            "1024,0,1024,264,721,262,721,576,0,576,0,0"
          ];
        };
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

  systemd.services.frigate.serviceConfig = {
    EnvironmentFile = config.age.secrets.frigateVars.path;
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
  };

  services.caddy.virtualHosts =
    let
      inherit (inputs.nix-resources.secrets) fqDomain;
    in
    {
      "cctv.${fqDomain}".extraConfig = ''
        import lan_only
        reverse_proxy http://127.0.0.1:5000
      '';
    };

  virtualisation.vmVariant = {
    # NOTE: Use VLC to stream a test RTSP stream on localhost port 8554
    cfg.rtspAddress = _: _: "rtsp://10.0.2.2:8554/";

    systemd.services.ctrld.serviceConfig = {
      EnvironmentFile = mkVMOverride
        (pkgs.writeText "frigate-vars" ''
          FRIGATE_MQTT_USER=frigate
          FRIGATE_MQTT_PASSWORD=test
        '').outPath;
      IPAddressDeny = mkVMOverride "";
      IPAddressAllow = mkVMOverride "";
    };

    # 5000 is for webinterface and 8554 is for RTSP streams
    networking.firewall.allowedTCPPorts = [ 5000 8554 ];
    networking.firewall.allowedUDPPorts = [ 8554 ];
  };
}
