{ username
, config
, lib
, ...
}:
lib.mkIf (config.modules.programs.steam.enable) {
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.gamescope.enable = true;

  hardware = {
    steam-hardware.enable = true;
  };
}
