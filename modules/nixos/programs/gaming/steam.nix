{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf optionals optional;
  cfg = config.${ns}.programs.gaming.steam;
  gamingCfg = config.${ns}.programs.gaming;
in
mkIf cfg.enable {
  # -- Common steam launch commands --
  # Standard  : mangohud gamemoderun %command%
  # FPS Limit : MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope : gamescope -W 2560 -H 1440 -f -r 165 --mangoapp -- gamemoderun %command%
  userPackages = with pkgs; [
    steam-run
    protontricks
  ];

  # Temporarily use appinfo_v29 branch to fix
  # https://github.com/Matoking/protontricks/issues/304
  nixpkgs.overlays = [
    (final: prev: {
      protontricks =
        (prev.protontricks.overrideAttrs {
          src = final.fetchFromGitHub {
            owner = "Matoking";
            repo = "protontricks";
            rev = "f7b1fa33b0438dbd72f7222703f8442e40edc510";
            hash = "sha256-t794WEMJx/JNX3gTMHfgquFWB7yXkleW07+QURm1NPM=";
          };
        }).override
          {
            vdf = final.python312Packages.vdf.overrideAttrs {
              src = final.fetchFromGitHub {
                owner = "Matoking";
                repo = "vdf";
                rev = "981cad270c2558aeb8eccaf42cfcf9fabbbed199";
                hash = "sha256-OPonFrYrEFYtx0T2hvSYXl/idsm0iDPwqlnm1KbTPIo=";
              };
            };
          };
    })
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = (
        pkgs:
        optionals gamingCfg.gamescope.enable (
          with pkgs;
          [
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
          ]
        )
      );
      extraLibraries = (pkgs: optional gamingCfg.gamemode.enable pkgs.gamemode.lib);
    };
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # So that protontricks can find proton-ge
  environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATHS =
    lib.makeSearchPathOutput "steamcompattool" ""
      [ pkgs.proton-ge-bin ];

  persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
  ];
}
