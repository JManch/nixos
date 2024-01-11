{ username
, hostname
, outputs
, config
, pkgs
, lib
, ...
}:
let
  homeConfig = outputs.nixosConfigurations.${hostname}.config.home-manager.users.${username};
in
lib.mkIf (config.modules.programs.gaming.enable) {

  environment.systemPackages = [
    pkgs.libnotify
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
        # TODO: Make this modular
        start = "${homeConfig.wayland.windowManager.hyprland.package}/bin/hyprctl keyword monitor DP-1,2560x1440@165,2560x0,1 && ${pkgs.libnotify}/bin/notify-send --urgency=critical -t 3000 'GameMode started'";
        end = "${homeConfig.wayland.windowManager.hyprland.package}/bin/hyprctl keyword monitor DP-1,2560x1440@144,2560x0,1 && ${pkgs.libnotify}/bin/notify-send --urgency=critical -t 3000 'GameMode ended'";
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
