# Issues
# - OpenXR games using Proton do not currently work.
#   https://github.com/ValveSoftware/Proton/issues/7382
# - The input in some OpenVR games that use legacy controls (such as Boneworks)
#   does not work.
# - Some games are broken with Monado so require suffering with SteamVR
{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  username,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    singleton
    mkOption
    types
    ;
  inherit (config.${ns}.core) device;
  inherit (config.${ns}.system) audio;
  inherit (device) primaryMonitor gpu;
  systemctl = getExe' pkgs.systemd "systemctl";
  lighthouse = getExe pkgs.lighthouse-steamvr;
in
{
  opts.audio = {
    card = mkOption {
      type = types.str;
      description = "Name of the Index audio card from `pact list cards`";
    };

    profile = mkOption {
      type = types.str;
      description = "Name of the Index audio profile from `pactl list cards`";
    };

    source = mkOption {
      type = types.str;
      description = "Name of the Index source device from `pactl list short sources`";
    };

    sink = mkOption {
      type = types.str;
      description = "Name of the Index sink device from `pactl list short sinks`";
    };
  };

  requirements = [
    "core.home-manager"
    "programs.gaming.gamemode"
    "system.audio"
    "services.lact"
    "hardware.bluetooth"
  ];

  asserts = [
    (audio.defaultSource != null && audio.defaultSink != null)
    "Valve Index requires the default sink and source devices to be set"
  ];

  nixpkgs.overlays = [
    (_: prev: {
      monado = prev.monado.overrideAttrs (old: {
        # nixpkgs-xr is missing an `or []` on patches
        patches = old.patches or [ ];
      });
    })
    inputs.nixpkgs-xr.overlays.default
  ];

  ns.userPackages = [
    pkgs.index_camera_passthrough
    (pkgs.makeDesktopItem {
      name = "monado";
      desktopName = "Monado";
      type = "Application";
      exec = "${systemctl} start --user monado";
      icon = (
        pkgs.fetchurl {
          url = "https://gitlab.freedesktop.org/uploads/-/system/group/avatar/5604/monado_icon_medium.png";
          hash = "sha256-Wx4BBHjNyuboDVQt8yV0tKQNDny4EDwRBtMSk9XHNVA=";
        }
      );
    })
    (pkgs.makeDesktopItem {
      name = "start-vr";
      desktopName = "Start VR";
      type = "Application";
      exec = "${systemctl} start --user valve-index";
      icon = "applications-system";
    })
    (pkgs.makeDesktopItem {
      name = "stop-vr";
      desktopName = "Stop VR";
      type = "Application";
      exec = "${systemctl} stop --user valve-index";
      icon = "applications-system";
    })
  ];

  ns.system.audio.alsaDeviceAliases = {
    ${cfg.audio.source} = "Valve Index";
    ${cfg.audio.sink} = "Valve Index";
  };

  # Enables asynchronous reprojection in SteamVR by allowing any application
  # to acquire high priority queues
  # https://github.com/NixOS/nixpkgs/issues/217119#issuecomment-2434353553
  ns.hardware.graphics.amd.kernelPatches = mkIf (gpu.type == "amd") [
    (pkgs.fetchpatch2 {
      url = "https://github.com/Frogging-Family/community-patches/raw/a6a468420c0df18d51342ac6864ecd3f99f7011e/linux61-tkg/cap_sys_nice_begone.mypatch";
      hash = "sha256-1wUIeBrUfmRSADH963Ax/kXgm9x7ea6K6hQ+bStniIY=";
    })
  ];

  # Proton version optimised for VRChat
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-rtsp-bin ];

  services.monado = {
    enable = true;
    # FIX: Remove this once monado builds again with our nixpkgs. Overlays
    # applied by nixpkgs-xr just override the package from our nixpkgs so
    # overlay build still fails.
    package = inputs.nixpkgs-xr.packages.${pkgs.system}.monado;
    forceDefaultRuntime = true;
    highPriority = true;
    defaultRuntime = true;
  };

  systemd.user.services.valve-index =
    let
      pactl = getExe' pkgs.pulseaudio "pactl";
      sleep = getExe' pkgs.coreutils "sleep";
    in
    {
      description = "Valve Index";
      partOf = [ "monado.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart =
          pkgs.writeShellScript "valve-index-start" # bash
            ''
              # Monado doesn't change audio devices so we have to do it
              # manually. SteamVR changes the default sink but doesn't set the
              # default source or the card profile.
              ${pactl} set-default-source "${cfg.audio.source}"
              ${pactl} set-source-mute "${cfg.audio.source}" 1
              ${pactl} set-card-profile "${cfg.audio.card}" "${cfg.audio.profile}"

              # The sink device can only bet set after the headset has powered on
              (${sleep} 10; ${pactl} set-default-sink "${cfg.audio.sink}") &
            '';

        ExecStop =
          pkgs.writeShellScript "valve-index-stop" # bash
            ''
              ${pactl} set-default-source ${audio.defaultSource}
              ${pactl} set-default-sink ${audio.defaultSink}
            '';
      };
    };

  systemd.user.services.monado =
    let
      openvrPaths = pkgs.writeText "monado-openvrpaths" ''
        {
          "config": [
            "/home/${username}/.local/share/Steam/config"
          ],
          "external_drivers": null,
          "jsonid": "vrpathreg",
          "log": [
            "/home/${username}/.local/share/Steam/logs"
          ],
          "runtime": [
            "${pkgs.opencomposite}/lib/opencomposite"
          ],
          "version": 1
        }
      '';
    in
    {
      requires = [ "valve-index.service" ];
      after = [ "valve-index.service" ];
      serviceConfig = {
        Slice = "app${lib.${ns}.sliceSuffix config}.slice";

        ExecStartPre = "-${pkgs.writeShellScript "monado-exec-start-pre" ''
          mkdir -p "$XDG_CONFIG_HOME/openvr"
          ln -sf ${openvrPaths} "$XDG_CONFIG_HOME/openvr/openvrpaths.vrpath"

          if [ ! -f "/tmp/disable-lighthouse-control" ]; then
            ${lighthouse} --state on
          fi
        ''}";

        ExecStopPost = "-${pkgs.writeShellScript "monado-exec-stop-post" ''
          rm -rf "$XDG_CONFIG_HOME"/{openxr,openvr}

          if [ ! -f "/tmp/disable-lighthouse-control" ]; then
            ${lighthouse} --state off
          fi
        ''}";
      };

      environment = {
        # Environment variable reference:
        # https://monado.freedesktop.org/getting-started.html#environment-variables

        # Using defaults from envision lighthouse profile:
        # https://gitlab.com/gabmus/envision/-/blob/main/src/profiles/lighthouse.rs

        XRT_COMPOSITOR_SCALE_PERCENTAGE = "180"; # super sampling of monado runtime
        XRT_COMPOSITOR_COMPUTE = "1";
        # These two enable a window that contains debug info and a mirror view
        # which monado calls a "peek window"
        XRT_DEBUG_GUI = "1";
        XRT_CURATED_GUI = "1";
        # Description I can't find the source of: Set to 1 to unlimit the
        # compositor refresh from a power of two of your HMD refresh, typically
        # provides a large performance boost
        # https://gitlab.freedesktop.org/monado/monado/-/merge_requests/2293
        U_PACING_APP_USE_MIN_FRAME_PERIOD = "1";

        # Display modes:
        # - 0: 2880x1600@90.00
        # - 1: 2880x1600@144.00
        # - 2: 2880x1600@120.02
        # - 3: 2880x1600@80.00
        XRT_COMPOSITOR_DESIRED_MODE = "0";

        # Use SteamVR tracking (requires calibration with SteamVR)
        STEAMVR_LH_ENABLE = "true";

        # Application launch vars:
        # SURVIVE_ vars are no longer needed
        # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc for Steam applications

        # Modifies super sampling of the game. Multiplied by
        # XRT_COMPOSITOR_SCALE_PERCENTAGE so if XRT_COMPOSITOR_SCALE_PERCENTAGE
        # is 300 and OXR_VIEWPORT_SCALE_PERCENTAGE is 33, the game will render
        # at 100% and the monado runtime (wlx-s-overlay etc..) will render at
        # 300%
        # OXR_VIEWPORT_SCALE_PERCENTAGE=100

        # If using Lact on an AMD GPU can set GAMEMODE_CUSTOM_ARGS=vr when using
        # gamemoderun command to automatically enable the VR power profile

        # Baseline launch options for Steam games:
        # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc GAMEMODE_CUSTOM_ARGS=vr gamemoderun %command%
      };
    };

  # Fix for audio cutting out when GPU is under load
  # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Troubleshooting#stuttering-audio-in-virtual-machine
  services.pipewire.wireplumber.extraConfig."99-valve-index"."monitor.alsa.rules" = singleton {
    matches = singleton {
      "node.name" = "${cfg.audio.sink}";
    };
    actions.update-props = {
      # This adds latency so set to minimum value that fixes problem
      "api.alsa.period-size" = 1024;
      "api.alsa.headroom" = 8192;
    };
  };

  ns.hm = {
    ${ns}.desktop = {
      services.waybar.audioDeviceIcons.${cfg.audio.sink} = "";
      hyprland.namedWorkspaces.VR = "monitor:${primaryMonitor.name}";

      hyprland.settings =
        let
          inherit (config.${ns}.hmNs.desktop.hyprland) modKey namedWorkspaceIDs;
        in
        {
          bind = [
            "${modKey}, Grave, workspace, ${namedWorkspaceIDs.VR}"
            "${modKey}SHIFT, Grave, movetoworkspace, ${namedWorkspaceIDs.VR}"
          ];

          windowrule = [
            "workspace ${namedWorkspaceIDs.VR} silent, class:^(monado-service)$"
            "center, class:^(monado-service)$"
          ];
        };
    };
  };
}
