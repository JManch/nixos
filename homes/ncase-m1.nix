{ lib, ... }:
{
  ${lib.ns} = {
    core = {
      configManager = true;
      backupFiles = true;
    };

    desktop = {
      enable = true;
      terminal = "Alacritty";
      windowManager = "hyprland";
      locker = "hyprlock";
      launcher = "fuzzel";
      xdg.lowercaseUserDirs = true;

      hyprland = {
        plugins = false;
        tearing = true;
        directScanout = true;
        logging = false;
        hyprcursor.package = null;
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        hypridle.enable = true;
        wayvnc.enable = true;
        awww.enable = true;
        hyprsunset.enable = true;

        lan-mouse = {
          enable = true;
          defaultHosts = [ "framework" ];
          defaultPositions."framework" = "bottom";
        };

        wallpaper = {
          randomise.enable = true;
          randomise.frequency = "*-*-* 05:00:00";
        };

        darkman = {
          enable = true;
          switchMethod = "hass";
          hassEntity = "joshua_dark_mode_brightness_threshold";
        };
      };
    };

    programs = {
      shell = {
        enable = true;
        atuin.enable = true;
        btop.enable = true;
        cava.enable = true;
        git.enable = true;
        fastfetch.enable = true;
        neovim.enable = true;

        taskwarrior = {
          enable = true;
          primaryClient = true;
        };
      };

      desktop = {
        alacritty.enable = true;
        ghostty.enable = true;
        tor-browser.enable = true;
        spotify.enable = true;
        feishin.enable = true;
        supersonic.enable = false;
        discord.enable = true;
        obs.enable = true;
        vscode.enable = true;
        mpv.enable = true;
        mpv.jellyfinShim.enable = true;
        chatterino.enable = true;
        images.enable = true;
        anki.enable = true;
        zathura.enable = true;
        qbittorrent.enable = true;
        filen-desktop.enable = true;
        multiviewer.enable = true;
        chromium.enable = true;
        foliate.enable = true;
        rnote.enable = true;
        jellyfin-media-player.enable = true;
        davinci-resolve.enable = false;
        signal.enable = true;

        firefox = {
          enable = true;
          backup = true;
          hideToolbar = true;
          runInRam = true;
          uiScale = 0.9;
        };

        gaming = {
          mangohud = {
            enable = true;
            fontSize = 18;
          };

          r2modman.enable = true;
          bottles.enable = false;
          prism-launcher.enable = true;
          mint.enable = false;
          osu.enable = true;
          beamng.enable = true;
          noita.enable = true;
        };
      };
    };

    services = {
      syncthing.enable = false;
      easyeffects.enable = true;
    };
  };

  home.stateVersion = "24.05";
}
