{ lib, inputs, ... }:
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
        feishin.enable = false;
        supersonic.enable = true;
        discord.enable = true;
        obs.enable = true;
        vscode.enable = true;
        mpv.enable = true;
        mpv.jellyfinShim.enable = true;
        chatterino.enable =
          assert lib.assertMsg (
            inputs.nixpkgs.rev == "62e0f05ede1da0d54515d4ea8ce9c733f12d9f08"
          ) "Re-enable chatterino";
          false;
        images.enable = true;
        anki.enable = true;
        zathura.enable = true;
        qbittorrent.enable = true;
        filen-desktop.enable = true;
        multiviewer-f1.enable = true;
        chromium.enable = true;
        foliate.enable = true;
        rnote.enable = true;
        jellyfin-media-player.enable = true;
        davinci-resolve.enable = false;

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
          prism-launcher.enable =
            assert lib.assertMsg (
              inputs.nixpkgs.rev == "62e0f05ede1da0d54515d4ea8ce9c733f12d9f08"
            ) "Re-enable prism-launcher";
            false;
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
