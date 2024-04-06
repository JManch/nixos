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

  # TODO: Get this working
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libsurvive
      xrgears
      opencomposite-helper
      index_camera_passthrough
    ];

    services.monado = {
      enable = true;
      defaultRuntime = true;
    };

    persistenceHome.files = [
      ".config/libsurvive/config.json"
    ];
  };
}
