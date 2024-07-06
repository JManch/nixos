{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf optionals optional;
  cfg = config.modules.programs.gaming.steam;
  gamingCfg = config.modules.programs.gaming;
in
mkIf cfg.enable
{
  # -- Common steam launch commands --
  # Standard  : mangohud gamemoderun %command%
  # FPS Limit : MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope : gamescope -W 2560 -H 1440 -f -r 165 --mangoapp -- gamemoderun %command%
  environment.systemPackages = with pkgs; [
    steam-run
    protontricks
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = (pkgs: optionals gamingCfg.gamescope.enable (with pkgs; [
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
      ]));
      extraLibraries = (pkgs:
        optional gamingCfg.gamemode.enable pkgs.gamemode.lib
      );
    };
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # So that protontricks can find proton-ge
  environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATHS =
    lib.makeSearchPathOutput "steamcompattool" "" [ pkgs.proton-ge-bin ];

  persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
  ];
}
