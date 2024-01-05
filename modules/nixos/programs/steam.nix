{ username
, config
, pkgs
, lib
, ...
}:
lib.mkIf (config.modules.programs.steam.enable) {

  environment.systemPackages = [
    pkgs.libnotify
    pkgs.mangohud
    pkgs.steam-run
  ];

  nixpkgs.config.packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      extraPkgs = pkgs: with pkgs; [
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
      ];
    };
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.gamescope.enable = true;

  programs.gamemode = {
    enable = true;
    settings = {
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send --urgency=critical -t 3000 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send --urgency=critical -t 3000 'GameMode ended'";
      };
    };
  };

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".steam"
      ".local/share/Steam"
      ".factorio"
    ];
  };
}
