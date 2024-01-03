{ config
, lib
, ...
}:
let
  cfg = config.modules.programs.obs;
in
lib.mkIf cfg.enable {
  programs.obs-studio.enable = true;

  impermanence.directories = [
    ".config/obs-studio"
  ];
}
