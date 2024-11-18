{
  ns,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    singleton
    attrNames
    mkAfter
    ;
  inherit (lib.${ns}) upperFirstChar;
  inherit (config.${ns}.services) frigate;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (secrets.general) devices userIds people;
  cameras = attrNames config.services.frigate.settings.cameras;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };

  entranceNotify = singleton {
    alias = "Entrance Person Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.driveway";
        state_filter = true;
        state_entity = "input_boolean.high_alert_surveillance";
        state_filter_states = [ "off" ];
        notify_device = devices.joshua.id;
        notify_group = "Adults Except ${upperFirstChar people.person5}";
        base_url = "https://home.${fqDomain}";
        group = "frigate-entrance-notification";
        title = "Security Alert";
        message = "A {{ label }} {{ 'is loitering' if loitering else 'was detected' }} in the entrance";
        update_thumbnail = true;
        alert_once = true;
        zone_filter = true;
        zones = [ "entrance" ];
      };
    };
  };

  highAlertNotify = map (camera: {
    alias = "High Alert ${upperFirstChar camera} Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.${camera}";
        state_filter = true;
        state_entity = "input_boolean.high_alert_surveillance";
        state_filter_states = [ "on" ];
        notify_device = devices.joshua.id;
        notify_group = "Adults Except ${upperFirstChar people.person5}";
        sticky = true;
        group = "frigate-notification";
        base_url = "https://home.${fqDomain}";
        title = "Security Alert";
        ios_live_view = "camera.${camera}";
        message = "A {{ label }} {{ 'is loitering' if loitering else 'was detected' }} on the {{ camera_name }} camera";
        color = "#f44336";
        update_thumbnail = true;
      };
    };
  }) cameras;

  catNotify = map (camera: {
    alias = "${upperFirstChar camera} Cat Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.${camera}";
        notify_device = devices.joshua.id;
        notify_group = "Adults Except ${upperFirstChar people.person5}";
        sticky = true;
        group = "frigate-cat-notification";
        base_url = "https://home.${fqDomain}";
        ios_live_view = "camera.${camera}";
        title = "Cat Detected";
        mess = "A cat {{ 'is loitering' if loitering else 'was detected' }} on the {{ camera_name }} camera";
        color = "#f44336";
        update_thumbnail = true;
        labels = [ "cat" ];
      };
    };
  }) cameras;
in
mkIf frigate.enable {
  services.home-assistant.config = {
    automation = entranceNotify ++ highAlertNotify ++ catNotify;

    input_boolean.high_alert_surveillance = {
      name = "High Alert Surveillance";
      icon = "mdi:cctv";
    };

    lovelaceConfig.views = mkAfter (singleton {
      title = "CCTV";
      path = "cctv";
      type = "sections";
      max_columns = 2;
      subview = true;
      sections = [
        {
          title = "Live Views";
          type = "grid";
          cards = map (camera: {
            cameras = singleton {
              camera_entity = "camera.${camera}";
              frigate.url = "https://cctv.${fqDomain}";
              live_provider = "go2rtc";
              go2rtc.modes = [ (if frigate.webrtc.enable then "webrtc" else "mse") ];
            };
            live = {
              show_image_during_load = true;
              transition_effect = "none";
            };
            menu = {
              style = "hover-card";
              buttons = {
                cameras.enabled = false;
                expand.enabled = false;
                fullscreen.enabled = true;
                timeline.enabled = true;
              };
            };
            performance.profile = "low";
            type = "custom:frigate-card";
          }) cameras;
        }
        {
          title = "Last Seen";
          type = "grid";
          cards = map (camera: {
            show_state = true;
            show_name = false;
            camera_view = "auto";
            entity = "image.${camera}_person";
            type = "picture-entity";
            layout_options = {
              grid_columns = 2;
              grid_rows = "auto";
            };
          }) cameras;
        }
        {
          title = "Settings";
          type = "grid";
          cards =
            (singleton {
              type = "tile";
              entity = "input_boolean.high_alert_surveillance";
              name = "High Alert Mode";
              color = "red";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            })
            ++ map (camera: {
              type = "tile";
              entity = "switch.${camera}_detect";
            }) cameras;
        }
        {
          title = "Debug";
          type = "grid";
          cards = map (camera: {
            type = "tile";
            entity = "binary_sensor.${camera}_motion";
          }) cameras;
          visibility = singleton {
            condition = "user";
            users = [ userIds.joshua ];
          };
        }
      ];
    });
  };
}
