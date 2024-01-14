{ lib
, pkgs
, config
, inputs
, username
, ...
} @ args:
let
  homeConfig = lib.utils.homeConfig args;
in
lib.mkIf (config.modules.programs.gaming.enable) {
  # TODO: Split up this functionality into a gaming module
  # Consider moving to home manager, but having programs.steam is nice

  # -- Common steam launch commands --
  # Standard:
  # - mangohud gamemoderun %command%
  # FPS Limit:
  # - MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope:
  # - gamescope -W 2560 -H 1440 -f -r 165 -- mangohud gamemoderun %command%

  environment.systemPackages = with pkgs; [
    steam-run
    r2modman
    protontricks
    # install lutris games in ~/files/games
    (pkgs.lutris.override {
      extraPkgs = pkgs: with pkgs; [
        # I use wine-ge which comes packaged with Lutris. Without a system wine
        # install lutris complains for some reason so we have to add it here,
        # even though it won't be used.
        wineWowPackages.stable
      ];
    })
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = (pkgs: with pkgs; [
        # Steam runs in it's own FHS environment
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
      extraProfile = "export STEAM_EXTRA_COMPAT_TOOLS_PATHS='${inputs.nix-gaming.packages.${pkgs.system}.proton-ge}'";
    };
    gamescopeSession.enable = true;
  };

  programs.gamescope = {
    enable = true;
    # Would like to enable but it causes gamescope to stop working in lutris and steam
    # https://discourse.nixos.org/t/unable-to-activate-gamescope-capsysnice-option/37843
    capSysNice = false;
  };

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".steam"
      ".local/share/Steam"
      ".local/share/lutris"
      ".config/lutris"
      ".cache/lutris"
      ".factorio"
      ".config/r2modman"
    ];
  };
}
