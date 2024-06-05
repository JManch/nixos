{ lib
, pkgs
, inputs
, config
, ...
}:
let
  cfg = config.modules.hardware.vr;
in
{
  imports = [
    # Provides overlays for latest versions of monado, opencomposite, index_camera_passthrough
    inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
  ];

  # Notes on VR with Valve Index:
  # SteamVR on Linux is notoriously broken. From some quick testing I found
  # that SteamVR had good controller tracking but the rendering had
  # unplayable latency.

  # Monado is an OpenXR runtime. On their website they suggest using the
  # open-source library libsurvive for tracking. In practice I found it
  # provided unusable tracking quality. Instead using SteamVR tracking with
  # steamvr_lh was much better (note that when using steamvr_lh, SteamVR must
  # be used for playspace calibration). Although the controller tracking in
  # tracking-centric games (e.g. Beat Saber, Climbey) was still worse than in
  # native SteamVR, the rendering latency and stability is significantly better
  # and indistinguishable to Windows (providing performance was on-par).

  # Since Monado is an OpenXR runtime it needs the translation layer
  # opencomposite to use OpenVR. Steam has a tendency to override the
  # openvrpaths.vrpath file with its own OpenVR runtime, so make sure it's a
  # read-only file. Using home-manager solves this.

  # Issues
  # OpenXR games using Proton do not currently work.
  # https://github.com/ValveSoftware/Proton/issues/7382

  # The input in some OpenVR games that use legacy controls (such as Boneworks)
  # does not work.

  # Performance is noticeably worse than Windows but I haven't put a lot of
  # effort into optimising it.

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      opencomposite-helper
      index_camera_passthrough
    ];

    services.monado = {
      enable = true;
      defaultRuntime = true;
    };

    systemd.user.services.monado.environment = {
      STEAMVR_LH_ENABLE = "1";
      XRT_COMPOSITOR_COMPUTE = "1";
    };

    hm.xdg.configFile."openxr/1/active_runtime.json".text = /*json*/ ''
      {
        "file_format_version": "1.0.0",
        "runtime": {
            "name": "Monado",
            "library_path": "${pkgs.monado}/lib/libopenxr_monado.so"
        }
      }
    '';

    hm.xdg.configFile."openvr/openvrpaths.vrpath".text = /*json*/ ''
      {
        "config": [
          "${config.hm.xdg.dataHome}/Steam/config"
        ],
        "external_drivers": null,
        "jsonid": "vrpathreg",
        "log": [
          "${config.hm.xdg.dataHome}/Steam/logs"
        ],
        "runtime": [
          "${pkgs.opencomposite}/lib/opencomposite"
        ],
        "version": 1
      }
    '';
  };
}
