{ lib
, pkgs
, inputs
, config
, ...
}:
let
  cfg = config.modules.programs.obs;
in
lib.mkIf cfg.enable {
  # The folders in this directory are OBS profiles which can be
  # imported/exported in OBS

  # Need version 30.0.2 otherwise screen cap is broken
  programs.obs-studio = {
    enable = true;
    package = inputs.nixpkgs-master.legacyPackages.${pkgs.system}.obs-studio;
  };

  impermanence.directories = [
    ".config/obs-studio"
  ];
}
