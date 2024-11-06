{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.gaming.steam;
in
lib.mkIf cfg.enable {
  # -- Common steam launch commands --
  # Standard  : mangohud gamemoderun %command%
  # FPS Limit : MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope : gamescope -W 2560 -H 1440 -f -r 165 --mangoapp -- gamemoderun %command%
  userPackages = [ pkgs.steam-run ];

  programs.steam = {
    enable = true;
    protontricks.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
  ];
}
