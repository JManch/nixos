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

      style = {
        cornerRadius = 16;
        gapSize = 6;
      };

      hyprland = {
        vrr = true;
        tearing = true;
        animations = true;
        directScanout = false; # causing flash when switching from fullscreen workspaces
        secondaryModKey = "SUPER"; # for some reason VMs ignore keyd remaps
        settings.device = lib.singleton {
          name = "pixa3854:00-093a:0274-touchpad";
          accel_profile = "adaptive";
        };
      };

      programs = {
        hyprlock.enable = true;
        fuzzel.enable = true;

        lan-mouse = {
          enable = true;
          interfaces = [
            "wg-home"
            "wg-home-minimal"
          ];
        };
      };

      services = {
        dunst.enable = true;
        hyprsunset.enable = true;
        wluma.enable = false;
        hypridle.enable = true;
        hyprpaper.enable = true;
        darkman.enable = true;
        poweralertd.chargeThreshold = 80;

        waybar = {
          enable = true;
          bottom = true;
          powerOffMethod = "hibernate";
        };

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
        taskwarrior.enable = true;
      };

      desktop = {
        alacritty.enable = true;
        discord.enable = true;
        spotify.enable = true;
        chatterino.enable = true;
        supersonic.enable = true;
        chromium.enable = true;
        multiviewer.enable = true;
        obs.enable = true;
        images.enable = true;
        mpv.enable = true;
        mpv.jellyfinShim.enable = true;
        tor-browser.enable = true;
        qbittorrent.enable = true;
        jellyfin-media-player.enable = true;
        zathura.enable = true;
        rnote.enable = true;
        vscode.enable = true;
        anki.enable = true;

        firefox = {
          enable = true;
          backup = true;
          runInRam = true;
          hideToolbar = true;
        };

        gaming = {
          mangohud = {
            enable = true;
            noShiftR = true;
            cpuName = "HX 370";
            gpuName = "890M";
          };

          prism-launcher.enable = true;
          beamng.enable = true;
        };
      };
    };
  };

  home.stateVersion = "25.05";
}
