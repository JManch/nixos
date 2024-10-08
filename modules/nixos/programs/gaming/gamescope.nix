{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${ns}.programs.gaming.gamescope;
  gamingCfg = config.${ns}.programs.gaming;
in
mkIf cfg.enable {
  programs.steam = mkIf gamingCfg.steam.enable { gamescopeSession.enable = true; };

  programs.gamescope = {
    enable = true;
    # Would like to enable this but it causes gamescope to stop working in lutris and steam
    # https://discourse.nixos.org/t/unable-to-activate-gamescope-capsysnice-option/37843
    capSysNice = false;
  };
}
