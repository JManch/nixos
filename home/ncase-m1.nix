{ lib
, pkgs
, config
, inputs
, ...
}:
let
  nix-resources = inputs.nix-resources.packages.${pkgs.system};
in
{
  imports = [ ./core.nix ];

  modules = {
    shell = {
      enable = true;
      sillyTools = true;
    };

    desktop = {
      windowManager = "Hyprland";

      hyprland = {
        tearing = true;
        directScanout = false;
        logging = false;
      };

      terminal = {
        exePath = lib.getExe config.programs.alacritty.package;
        class = "Alacritty";
      };

      style = {
        cursorSize = 24;
        cornerRadius = 10;
        borderWidth = 2;
        gapSize = 10;

        font = {
          family = "BerkeleyMono Nerd Font";
          package = nix-resources.berkeley-mono-nerdfont;
        };
      };

      programs = {
        swaylock.enable = true;
        # Waiting for the nix hm module to mature
        hyprlock.enable = false;
        anyrun.enable = true;
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        wlsunset.enable = true;

        hypridle = {
          enable = true;
          lockTime = 3 * 60;
          screenOffTime = (3 * 60) + 30;
        };

        wallpaper = {
          randomise = true;
          randomiseFrequency = "*-*-* 05:00:00"; # 5am everyday
        };
      };
    };

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      cava.enable = true;
      firefox.enable = true;
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
      chatterino.enable = true;
      images.enable = true;
      anki.enable = true;
      zathura.enable = true;
      qbittorrent.enable = true;
      mangohud.enable = true;
      r2modman.enable = true;
      lutris.enable = true;
      filenDesktop.enable = true;
      multiviewerF1.enable = true;
    };

    services = {
      syncthing.enable = true;

      easyeffects = {
        enable = true;
      };
    };
  };
}
