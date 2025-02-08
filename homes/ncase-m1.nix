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
      xdg.lowercaseUserDirs = true;

      hyprland = {
        plugins = false;
        tearing = true;
        # Causes artifacting https://github.com/hyprwm/Hyprland/issues/6994
        directScanout = false;
        logging = false;
        hyprcursor.package = null;
      };

      programs = {
        swaylock.enable = false;
        hyprlock.enable = true;
        fuzzel.enable = true;
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        hypridle.enable = true;
        wayvnc.enable = true;
        swww.enable = true;
        wlsunset.enable = true;

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
        torBrowser.enable = true;
        spotify.enable = true;
        feishin.enable = false;
        supersonic.enable = true;
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
        filenDesktop.enable = true;
        multiviewerF1.enable = true;
        chromium.enable = true;
        foliate.enable = true;
        rnote.enable = true;
        jellyfinMediaPlayer.enable = true;
        davinciResolve.enable = false;

        firefox = {
          enable = true;
          backup = true;
          hideToolbar = true;
          runInRam = true;
          uiScale = 0.9;
        };

        gaming = {
          mangohud.enable = true;
          r2modman.enable = true;
          bottles.enable = true;
          prismLauncher.enable = true;
          mint.enable = true;
          ryujinx.enable = true;
          osu.enable = true;
          beamng.enable = true;
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
