{ lib, ... }:
{
  ${lib.ns} = {
    shell.enable = true;

    desktop = {
      enable = true;
      terminal = "Alacritty";
      windowManager = "hyprland";
      xdg.lowercaseUserDirs = true;

      hyprland = {
        plugins.enable = false;
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
        swww.enable = true;
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        wlsunset.enable = true;
        hypridle.enable = true;
        wayvnc.enable = false;
        darkman.enable = true;
        wluma.enable = true;

        wallpaper = {
          randomise.enable = true;
          randomise.frequency = "*-*-* 05:00:00";
        };
      };
    };

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      cava.enable = true;
      git.enable = true;
      neovim.enable = true;
      spotify.enable = true;
      discord.enable = true;

      firefox = {
        enable = true;
        hideToolbar = true;
        runInRam = true;
      };
    };
  };

  home.stateVersion = "24.11";
}
