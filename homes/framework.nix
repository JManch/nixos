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
        vrr = true;
        tearing = true;
        directScanout = true;
      };

      programs = {
        hyprlock.enable = true;
        fuzzel.enable = true;
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        wlsunset.enable = true;
        wluma.enable = true;
        hypridle.enable = true;
        hyprpaper.enable = true;
        darkman.enable = true;

        wallpaper = {
          randomise.enable = true;
          randomise.frequency = "*-*-* 05:00:00";
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
        neovim.enable = true;
        fastfetch.enable = true;
      };

      desktop = {
        alacritty.enable = true;
        discord.enable = true;
        chatterino.enable = true;
        supersonic.enable = true;
        chromium.enable = true;
        obs.enable = true;
        images.enable = true;
        mpv.enable = true;

        firefox = {
          enable = true;
          backup = true;
          runInRam = true;
          hideToolbar = true;
        };

        gaming = {
          mangohud.enable = true;
          prism-launcher.enable = true;
          beamng.enable = true;
        };
      };
    };
  };

  home.stateVersion = "25.05";
}
