{ lib
, pkgs
, config
, username
, ...
} @ args:
let
  homeConfig = lib.utils.homeConfig args;
in
lib.mkIf (config.modules.programs.gaming.enable) {

  # -- Common steam launch commands --
  # Standard:
  # - mangohud gamemoderun %command%
  # FPS Limit:
  # - MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%

  environment.systemPackages = with pkgs; [
    steam-run
    r2modman
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = (pkgs: with pkgs; [
        # gamemode # fixes libgamemode.so: cannot open shared object file 
        # mangohud
        # gamescope
        # These fix gamescope
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
      ]);
    };
    gamescopeSession.enable = true;
  };

  programs.gamescope.enable = true;

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".steam"
      ".local/share/Steam"
      ".factorio"
      ".config/r2modman"
    ];
  };
}
