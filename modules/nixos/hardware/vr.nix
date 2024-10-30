{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (config.${ns}.core) homeManager;
  inherit (config.hm.xdg) dataHome;
  inherit (config.${ns}.device) primaryMonitor gpu;
  cfg = config.${ns}.hardware.vr;
in
{
  # Issues
  # - OpenXR games using Proton do not currently work.
  #   https://github.com/ValveSoftware/Proton/issues/7382
  # - The input in some OpenVR games that use legacy controls (such as Boneworks)
  #   does not work.
  config = mkIf cfg.enable {
    assertions = lib.${ns}.asserts [
      homeManager.enable
      "VR requires home manager to be enabled"
    ];

    nixpkgs.overlays = [ inputs.nixpkgs-xr.overlays.default ];

    userPackages = with pkgs; [
      index_camera_passthrough
      wlx-overlay-s
    ];

    # Enables asynchronous reprojection in SteamVR by allowing any application
    # to acquire high priority queues
    # https://github.com/NixOS/nixpkgs/issues/217119#issuecomment-2434353553
    ${ns}.hardware.graphics.amd.kernelPatches = mkIf (gpu.type == "amd") [
      (pkgs.fetchpatch2 {
        url = "https://github.com/Frogging-Family/community-patches/raw/a6a468420c0df18d51342ac6864ecd3f99f7011e/linux61-tkg/cap_sys_nice_begone.mypatch";
        hash = "sha256-1wUIeBrUfmRSADH963Ax/kXgm9x7ea6K6hQ+bStniIY=";
      })
    ];

    services.monado = {
      enable = true;
      highPriority = true;
      defaultRuntime = true;
    };

    systemd.user.services.monado.environment = {
      # Environment variable reference:
      # https://monado.freedesktop.org/getting-started.html#environment-variables

      # Using defaults from envision lighthouse profile:
      # https://gitlab.com/gabmus/envision/-/blob/main/src/profiles/lighthouse.rs

      XRT_COMPOSITOR_SCALE_PERCENTAGE = "140"; # global super sampling
      XRT_COMPOSITOR_COMPUTE = "1";
      # These two enable a window that contains debug info and a mirror view
      # which monado calls a "peek window"
      XRT_DEBUG_GUI = "1";
      XRT_CURATED_GUI = "1";
      # Description I can't find the source of: Set to 1 to unlimit the
      # compositor refresh from a power of two of your HMD refresh, typically
      # provides a large performance boost
      U_PACING_APP_USE_MIN_FRAME_PERIOD = "1";

      # Use SteamVR tracking (requires calibration with SteamVR)
      STEAMVR_LH_ENABLE = "true";

      # Application launch envs:
      # SURVIVE_ envs are no longer needed
      # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc for Steam applications

      # Per-app supersampling applied after global XRT_COMPOSITOR_SCALE_PERCENTAGE.
      # I think super sampling with global gives higher quality.
      # OXR_VIEWPORT_SCALE_PERCENTAGE=100

      # If using Lact on an AMD GPU can set GAMEMODE_CUSTOM_ARGS=vr when using
      # gamemoderun command to automatically enable the VR power profile

      # Baseline launch options for Steam games:
      # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc GAMEMODE_CUSTOM_ARGS=vr gamemoderun %command%
    };

    hm = {
      xdg.configFile = {
        "openxr/1/active_runtime.json".source =
          config.environment.etc."xdg/openxr/1/active_runtime.json".source;

        "openvr/openvrpaths.vrpath".text = # json
          ''
            {
              "config": [
                "${dataHome}/Steam/config"
              ],
              "external_drivers": null,
              "jsonid": "vrpathreg",
              "log": [
                "${dataHome}/Steam/logs"
              ],
              "runtime": [
                "${pkgs.opencomposite}/lib/opencomposite"
              ],
              "version": 1
            }
          '';
      };

      ${ns}.desktop.hyprland.namedWorkspaces.VR = "monitor:${primaryMonitor.name}";
      desktop.hyprland.settings =
        let
          inherit (config.hm.${ns}.desktop.hyprland) modKey namedWorkspaceIDs;
        in
        {
          bind = [
            "${modKey}, Grave, workspace, ${namedWorkspaceIDs.VR}"
            "${modKey}SHIFT, Grave, movetoworkspace, ${namedWorkspaceIDs.VR}"
          ];

          windowrulev2 = [
            "workspace ${namedWorkspaceIDs.VR} silent, class:^(monado-service)$"
            "center, class:^(monado-service)$"
          ];
        };
    };
  };
}
