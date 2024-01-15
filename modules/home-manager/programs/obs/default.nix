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
  programs.obs-studio = {
    enable = true;
  };

  impermanence.directories = [
    ".config/obs-studio"
  ];
}
