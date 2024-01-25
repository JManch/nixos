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
    # Provides latest versions of monado, opencomposite, index_camera_passthrough
    inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
  ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libsurvive
      xrgears
    ];
  };

  # TODO: Waiting on:
  # - https://github.com/NixOS/nixpkgs/pull/245005 for easy monado config
  # - https://github.com/NixOS/nixpkgs/issues/282465 monado doesn't currently compile cause this is broken
  # - https://github.com/NixOS/nixpkgs/pull/258392
  # services.monado.enable = true;
}
