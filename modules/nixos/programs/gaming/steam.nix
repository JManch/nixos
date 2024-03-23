{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf optionals optional;
  cfg = config.modules.programs.gaming.steam;
  gamingCfg = config.modules.programs.gaming;
  proton-ge = pkgs.proton-ge-bin;
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
      extraPkgs = (pkgs: with pkgs;
        optionals gamingCfg.gamescope.enable [
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
      extraLibraries = (pkgs:
        optional gamingCfg.gamemode.enable pkgs.gamemode.lib
      );
    };
    extraCompatPackages = [ proton-ge ];
  };

  # So that protontricks can find proton-ge
  environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATHS = proton-ge;

  persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
    ".factorio"
  ];
}
