{ lib, pkgs, config, ... } @ args:
let
  inherit (lib) mkIf utils optionals;
  cfg = config.modules.programs.gaming.steam;
  gamingCfg = config.modules.programs.gaming;
  protonGe = (utils.flakePkgs args "nix-gaming").proton-ge;
in
mkIf cfg.enable
{
  # -- Common steam launch commands --
  # Standard  : mangohud gamemoderun %command%
  # FPS Limit : MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope : gamescope -W 2560 -H 1440 -f -r 165 -- mangohud gamemoderun %command%
  environment.systemPackages = with pkgs; [
    steam-run
    protontricks
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = (pkgs: with pkgs; optionals gamingCfg.gamescope.enable [
        # These fix gamescope in steam's FSH environment
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
      extraProfile = "export STEAM_EXTRA_COMPAT_TOOLS_PATHS='${protonGe}'";
    };
  };

  # So that protontricks can find proton-ge
  environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATHS = protonGe;

  persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
    ".factorio"
  ];
}
