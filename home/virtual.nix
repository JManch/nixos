{ lib
, pkgs
, inputs
, config
, ...
}:
{
  imports = [ ./core.nix ];

  modules = {
    desktop = {
      windowManager = "Hyprland";

      hyprland = {
        modKey = "ALT";
        blur = false;
        logging = true;
      };

      terminal = {
        exePath = lib.getExe config.programs.alacritty.package;
        class = "Alacritty";
      };

      style.font = {
        family = "BerkeleyMono Nerd Font";
        package = inputs.nix-resources.packages.${pkgs.system}.berkeley-mono-nerdfont;
      };

      programs = {
        anyrun.enable = true;
      };

      services = {
        wallpaper.randomise = true;
        waybar.enable = true;
        dunst.enable = true;
      };
    };

    shell.enable = true;

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      firefox.enable = false;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };
  };
}
