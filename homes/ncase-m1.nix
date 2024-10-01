{
  ns,
  lib,
  config,
  ...
}:
{
  ${ns} = {
    core = {
      configManager = true;
      backupFiles = true;
    };

    shell = {
      enable = true;
      sillyTools = true;
    };

    desktop = {
      enable = true;
      windowManager = "hyprland";
      xdg.lowercaseUserDirs = true;

      hyprland = {
        tearing = true;
        # Causes artifacting https://github.com/hyprwm/Hyprland/issues/6994
        directScanout = false;
        logging = false;
      };

      terminal = {
        exePath = lib.getExe config.programs.alacritty.package;
        class = "Alacritty";
      };

      programs = {
        swaylock.enable = false;
        hyprlock.enable = true;
        fuzzel.enable = true;
        swww.enable = true;
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        wlsunset.enable = true;
        hypridle.enable = true;

        wallpaper = {
          randomise.enable = true;
          randomise.frequency = "*-*-* 05:00:00";
        };

        darkman = {
          enable = true;
          switchMethod = "hass";
        };
      };
    };

    programs = {
      alacritty.enable = true;
      foot.enable = true;
      btop.enable = true;
      cava.enable = true;
      torBrowser.enable = true;
      git.enable = true;
      neovim.enable = true;
      spotify.enable = true;
      fastfetch.enable = true;
      discord.enable = true;
      obs.enable = true;
      vscode.enable = true;
      stremio.enable = true;
      mpv.enable = true;
      mpv.jellyfinShim.enable = true;
      chatterino.enable = true;
      images.enable = true;
      anki.enable = true;
      zathura.enable = true;
      qbittorrent.enable = true;
      filenDesktop.enable = true;
      multiviewerF1.enable = true;
      foliate.enable = true;
      rnote.enable = true;
      jellyfin-media-player.enable = true;

      firefox = {
        enable = true;
        hideToolbar = true;
        runInRam = true;
      };

      taskwarrior = {
        enable = true;
        primaryClient = true;
      };

      gaming = {
        steam.enable = true;
        mangohud.enable = true;
        r2modman.enable = true;
        lutris.enable = true;
        prism-launcher.enable = true;
        mint.enable = true;
        ryujinx.enable = true;
      };
    };

    services = {
      syncthing.enable = false;
      easyeffects.enable = true;
    };
  };

  home.stateVersion = "24.05";
}
